require 'gnista'
require 'securerandom'

module Hammerspace
  module Backend

    class Sparkey < Base
      def [](key)
        close_logwriter
        open_hash

        @hash ? @hash[key] : nil
      end

      def []=(key, value)
        close_hash
        open_logwriter

        @logwriter[key] = value
      end

      def close
        close_logwriter
        close_hash
      end

      def delete(key)
        close_hash
        open_logwriter

        @logwriter.del(key)
      end

      def each(&block)
        close_logwriter

        # Open a private copy of the hash to ensure isolation during iteration.
        # Further, Gnista segfaults if the hash is closed during iteration (e.g.,
        # from interleaved reads and writes), so a private copy ensures that
        # the hash is only closed once iteration is complete.
        hash = open_hash_private

        return block_given? ? nil : Enumerator.new {} unless hash

        if block_given?
          begin
            hash.each(&block)
          ensure
            hash.close
          end
        else
          # Gnista does not support each w/o a block; emulate the behavior here.
          Enumerator.new do |y|
            begin
              hash.each { |*args| y << args }
            ensure
              hash.close
            end
          end
        end
      end

      def empty?
        close_logwriter
        open_hash

        @hash ? @hash.empty? : true
      end

      def has_key?(key)
        close_logwriter
        open_hash

        @hash ? @hash.include?(key) : false
      end

      def has_value?(value)
        each { |k,v| return true if v == value }
        false
      end

      def merge!(hash)
        hash.each { |key,value| self[key] = value }
      end

      def keys
        close_logwriter
        open_hash

        @hash ? @hash.keys : []
      end

      def size
        close_logwriter
        open_hash

        @hash ? @hash.size : 0
      end

      def values
        close_logwriter
        open_hash

        @hash ? @hash.values : []
      end

      private

      def open_logwriter
        @logwriter ||= begin
          # Create a new log file in a new, private directory and copy the
          # contents of the current hash over to it. Writes to this new file
          # can happen independently of all other writers, so no locking is
          # required.
          regenerate_uid
          ensure_path_exists(new_path)
          logwriter = Gnista::Logwriter.new(new_log_path)
          each { |key,value| logwriter[key] = value }
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
          Gnista::Hash.write(new_hash_path, new_log_path)

          # Create a symlink pointed at the private directory. Give the symlink
          # a temporary name for now. Note that the target of the symlink is
          # the raw uid, not a full path, since symlink targets are relative.
          File.symlink(@uid, "#{new_path}.tmp")

          # Rename the symlink pointed at the new directory to "current", which
          # atomically promotes the new directory to be the current directory.
          # Only one process should do this at a time, and no readers should
          # try to open files while this is happening, so we need to take an
          # exclusive lock for this operation. While we are holding the lock,
          # note the old target of the "current" symlink, if it exists.
          old_path = nil
          lock_for_write do
            old_path = File.readlink(cur_path) if File.symlink?(cur_path)
            File.rename("#{new_path}.tmp", cur_path)
          end

          # If there was an existing "current" symlink, the directory it
          # pointed to is now obsolete. Remove it and its contents.
          FileUtils.rm_rf(old_path, :secure => true) if old_path
        end
      end

      def open_hash
        @hash ||= open_hash_private
      end

      def open_hash_private
        # Take a shared lock before opening files. This avoids a situation
        # where a writer updates the files after we have opened the hash file
        # but before we have opened the log file. Once we have open file
        # descriptors it doesn't matter what happens to the files, so we can
        # release the lock immediately after opening.
        lock_for_read do
          begin
            Gnista::Hash.new(cur_hash_path, cur_log_path)
          rescue GnistaException
          end
        end
      end

      def close_hash
        if @hash
          @hash.close
          @hash = nil
        end
      end

      def regenerate_uid
        @uid = SecureRandom.uuid
      end

      def new_path
        File.join(path, @uid)
      end

      def new_log_path
        File.join(new_path, 'hammerspace.spl')
      end

      def new_hash_path
        File.join(new_path, 'hammerspace.spi')
      end

      def cur_path
        File.join(path, 'current')
      end

      def cur_log_path
        File.join(cur_path, 'hammerspace.spl')
      end

      def cur_hash_path
        File.join(cur_path, 'hammerspace.spi')
      end

    end

  end
end
