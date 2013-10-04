require 'gnista'

module Hammerspace
  module Backend

    class Sparkey < Base

      def []=(key, value)
        close_hash
        open_logwriter

        @logwriter[key] = value
      end

      def [](key)
        close_logwriter
        open_hash

        @hash[key]
      end

      def close
        close_logwriter
        close_hash
      end

      private

      def log_path
        File.join(path, 'hammerspace.spl')
      end

      def hash_path
        File.join(path, 'hammerspace.spi')
      end

      def open_logwriter
        @logwriter ||= begin
          ensure_path_exists
          if File.exist?(log_path)
            Gnista::Logwriter.new(log_path, :append)
          else
            Gnista::Logwriter.new(log_path)
          end
        end
      end

      def close_logwriter
        if @logwriter
          @logwriter.close
          @logwriter = nil
          Gnista::Hash.write(hash_path, log_path)
        end
      end

      def open_hash
        @hash ||= begin
          Gnista::Hash.new(hash_path, log_path)
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
