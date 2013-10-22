module Hammerspace
  module Backend

    class Base

      attr_reader :path
      attr_reader :options

      def initialize(path, options={})
        @path    = path
        @options = options
      end

      protected

      def ensure_path_exists
        FileUtils.mkdir_p(path)
      end

      def lock_for_write
        ensure_path_exists
        File.open(File.join(path, 'hammerspace.lock'), File::CREAT) do |lockfile|
          lockfile.flock(File::LOCK_EX)
          yield
        end
      end

      def lock_for_read
        ensure_path_exists
        File.open(File.join(path, 'hammerspace.lock'), File::CREAT) do |lockfile|
          lockfile.flock(File::LOCK_SH)
          yield
        end
      end

    end

  end
end

# Require all backends
Dir[File.expand_path("../backend/*.rb", __FILE__)].each { |f| require f }
