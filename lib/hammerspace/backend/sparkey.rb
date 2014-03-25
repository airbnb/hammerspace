require 'sparkey'
require 'ffi'
require 'fileutils'
require 'securerandom'

module Hammerspace
  module Backend

    class Sparkey < Base
      include ::Sparkey::Errors

      def check_fs
        super
        warn_dir_cleanup unless dir_cleanup_works?
      end

      def dir_cleanup_works?
        dir_cleanup_works = false
        ensure_path_exists(path)
        begin
          Dir.mktmpdir('dir_cleanup_works.', path) do |tmpdir|
            test       = File.join(tmpdir, 'test')
            test_tmp   = File.join(tmpdir, 'test.tmp')
            test_file  = File.join(test, 'file')
            test1      = File.join(tmpdir, 'test.1')
            test1_file = File.join(test1, 'file')
            test2      = File.join(tmpdir, 'test.2')
            test2_file = File.join(test2, 'file')

            Dir.mkdir(test1)
            FileUtils.touch(test1_file)
            File.symlink(File.basename(test1), test)

            File.open(test_file) do
              Dir.mkdir(test2)
              FileUtils.touch(test2_file)
              File.symlink(File.basename(test2), test_tmp)
              File.rename(test_tmp, test)

              FileUtils.rm_rf(test1, :secure => true)

              dir_cleanup_works = File.directory?(test1) == false
            end
          end
        rescue
        end
        dir_cleanup_works
      end

      def [](key)
        close_logwriter
        open_hash

        if @hash
          seek(key)
          return get_value if @iterator.active?
        end
        frontend.default(key)
      end

      def []=(key, value)
        close_hash
        open_logwriter

        @logwriter.put(key, value)
        value
      end

      def clear
        close_hash
        close_logwriter_clear

        frontend
      end

      def close
        close_logwriter
        close_hash
      end

      # TODO: This currently always returns nil. If the key is not found,
      # return the default value. Also, support block usage.
      def delete(key)
        close_hash
        open_logwriter

        @logwriter.delete(key)
      end

      def each(&block)
        close_logwriter

        # Open a private copy of the hash to ensure isolation during iteration.
        hash = open_hash_private

        unless hash
          return block_given? ? nil : Enumerator.new {}
        end

        if block_given?
          begin
            each_with_iterator(hash, &block)
          ensure
            hash.close
          end
          frontend
        else
          Enumerator.new do |y|
            begin
              each_with_iterator(hash) { |*args| y << args }
            ensure
              hash.close
            end
          end
        end
      end

      def has_key?(key)
        close_logwriter
        open_hash

        if @hash
          seek(key)
          return @iterator.active?
        end
        false
      end

      def keys
        close_logwriter
        open_hash

        array = []
        each_with_iterator(@hash) { |key,value| array << key }
        array
      end

      def replace(hash)
        close_hash
        open_logwriter(false)

        merge!(hash)
      end

      def size
        close_logwriter
        open_hash

        @hash ? @hash.entry_count : 0
      end

      def uid
        close_logwriter
        open_hash

        @uid
      end

      def values
        close_logwriter
        open_hash

        array = []
        each_with_iterator(@hash) { |key,value| array << value }
        array
      end

      private

      def open_logwriter(copy = true)
        @logwriter ||= begin
          # Create a new log file in a new, private directory and copy the
          # contents of the current hash over to it. Writes to this new file
          # can happen independently of all other writers, so no locking is
          # required.
          regenerate_uid
          ensure_path_exists(new_path)
          logwriter = ::Sparkey::LogWriter.new
          logwriter.create(File.join(new_path, 'hammerspace'), :compression_none, 0)
          each { |key,value| logwriter.put(key, value) } if copy
          logwriter
        end
      end

      def close_logwriter
        if @logwriter
          @logwriter.close
          @logwriter = nil

          # Create an index of the log file and write it to a hash file in the
          # same private directory. Again, this happens independently of all
          # other writers, so no locking is required.
          hashwriter = ::Sparkey::HashWriter.new
          hashwriter.create(File.join(new_path, 'hammerspace'))

          # Create a symlink pointed at the private directory. Give the symlink
          # a temporary name for now. Note that the target of the symlink is
          # the raw uid, not a full path, since symlink targets are relative.
          File.symlink(@uid, "#{new_path}.tmp")

          # Rename the symlink pointed at the new directory to "current", which
          # atomically promotes the new directory to be the current directory.
          # Only one process should do this at a time, and no readers should
          # try to open files while this is happening, so we need to take an
          # exclusive lock for this operation. While we are holding the lock,
          # note the old target of the "current" symlink if it exists.
          old_path = nil
          lock_for_write do
            old_path = File.readlink(cur_path) if File.symlink?(cur_path)
            File.rename("#{new_path}.tmp", cur_path)
          end

          # If there was an existing "current" symlink, the directory it
          # pointed to is now obsolete. Remove it and its contents.
          FileUtils.rm_rf(File.join(path, old_path), :secure => true) if old_path
        end
      end

      def close_logwriter_clear
        if @logwriter
          @logwriter.close
          @logwriter = nil

          # Delete the private directory and the new log file inside it.
          FileUtils.rm_rf(new_path, :secure => true)
        end

        # Remove the "current" symlink if it exists. Only one process should
        # do this at a time, and no readers should try to open files while
        # this is happening, so we need to take an exclusive lock for this
        # operation. While we are holding the lock, note the old target of
        # the "current" symlink if it exists.
        old_path = nil
        lock_for_write do
          if File.symlink?(cur_path)
            old_path = File.readlink(cur_path)
            File.unlink(cur_path)
          end
        end

        # If there was an existing "current" symlink, the directory it
        # pointed to is now obsolete. Remove it and its contents.
        FileUtils.rm_rf(File.join(path, old_path), :secure => true) if old_path
      end

      def open_hash
        # Take a shared lock before opening files. This avoids a situation
        # where a writer updates the files after we have opened the hash file
        # but before we have opened the log file. Once we have open file
        # descriptors it doesn't matter what happens to the files, so we can
        # release the lock immediately after opening. While we are holding the
        # lock, note the target of the "current" symlink.
        @hash ||= lock_for_read do
          begin
            hash = ::Sparkey::HashReader.new
            hash.open(File.join(cur_path, 'hammerspace'))

            @log = hash.log_reader
            @iterator = ::Sparkey::LogIterator.new(@log)

            @max_value_length = @log.max_value_length
            @value_buffer_ptr = FFI::MemoryPointer.new(:uint8, @max_value_length)
            @value_buffer_length_ptr = FFI::MemoryPointer.new(:uint64)

            @uid = File.readlink(cur_path)

            hash
          rescue ::Sparkey::Error
          end
        end
      end

      def open_hash_private
        # Take a shared lock before opening files. This avoids a situation
        # where a writer updates the files after we have opened the hash file
        # but before we have opened the log file. Once we have open file
        # descriptors it doesn't matter what happens to the files, so we can
        # release the lock immediately after opening.
        lock_for_read do
          begin
            hash = ::Sparkey::HashReader.new
            hash.open(File.join(cur_path, 'hammerspace'))
            hash
          rescue ::Sparkey::Error
          end
        end
      end

      def seek(key)
        key_length = key.bytesize
        key_ptr = FFI::MemoryPointer.new(:uint8, key_length).write_bytes(key)

        handle_status ::Sparkey::Native.hash_get(@hash.ptr, key_ptr, key_length, @iterator.ptr)
      end

      def get_value
        handle_status ::Sparkey::Native.logiter_fill_value(@iterator.ptr, @log.ptr, @max_value_length, @value_buffer_ptr, @value_buffer_length_ptr)

        @value_buffer_ptr.read_bytes(@value_buffer_length_ptr.read_uint64)
      end

      def each_with_iterator(hash)
        if hash
          iterator = ::Sparkey::HashIterator.new(hash)
          begin
            loop do
              iterator.next
              break unless iterator.active?
              yield iterator.get_key, iterator.get_value
            end
          ensure
            iterator.close
          end
        end
      end

      def close_hash
        if @hash
          @iterator.close
          @hash.close
          @hash = nil
        end
      end

      def regenerate_uid
        @uid = "#{Process.pid}_#{SecureRandom.uuid}"
      end

      def new_path
        File.join(path, @uid)
      end

      def cur_path
        File.join(path, 'current')
      end

      def warn_dir_cleanup
        warn "filesystem does not appear to allow removing directories when files " \
             "within are still in use. Directory cleanup may not behave as expected."
      end

    end

  end
end
