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

      def tmp_log_path
        # Ideally we would use Tempfile, but for some reason it was very slow.
        # (Specs went from taking ~1.5s to ~5s!)
        File.join(path, "hammerspace.spl.#{SecureRandom.uuid}.tmp")
      end

      def tmp_hash_path(tmp_log_path)
        base = File.basename(tmp_log_path).gsub(/^hammerspace\.spl\./, 'hammerspace.spi.')
        File.join(path, base)
      end

      def log_path
        File.join(path, 'hammerspace.spl')
      end

      def hash_path
        File.join(path, 'hammerspace.spi')
      end

      def open_logwriter
        @logwriter ||= begin
          # Create a new temporary log file and copy the contents of the
          # current hash over to it. Writes to this temporary file can happen
          # independently of all other writers, so no locking is required.
          # TODO: would FileUtils.cp be faster? but it doesn't compact...
          ensure_path_exists
          logwriter = Gnista::Logwriter.new(tmp_log_path)
          each { |key,value| logwriter[key] = value }
          logwriter
        end
      end

      def close_logwriter
        if @logwriter
          tmp_log_path = @logwriter.logpath
          tmp_hash_path = tmp_hash_path(tmp_log_path)

          @logwriter.close
          @logwriter = nil

          # Create an index of the temporary log file and write it to a
          # temporary hash file. Again, this happens independently of all other
          # writers, so no locking is required.
          Gnista::Hash.write(tmp_hash_path, tmp_log_path)

          # Promote the temporary hash and log files to the "final" versions
          # that will be used for reads. This operation is not atomic, so we
          # need to take an exclusive lock to block other writers and any
          # readers.
          lock_for_write do
            # TODO: handle errors and roll back
            File.rename(tmp_hash_path, hash_path)
            File.rename(tmp_log_path, log_path)
          end
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
            Gnista::Hash.new(hash_path, log_path)
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

    end

  end
end
