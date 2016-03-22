require 'fileutils'
require 'tempfile'

module Hammerspace
  module Backend

    # "Backend" class from which concrete backends extend
    #
    # Mixes in Enumerable and HashMethods to provide default implementations of
    # most methods that Ruby's hash supports. Also provides some basic file and
    # lock handling methods common to backends.
    class Base
      include Enumerable
      include HashMethods

      attr_reader :frontend
      attr_reader :path
      attr_reader :options

      def initialize(frontend, path, options={})
        @frontend = frontend
        @path     = path
        @options  = options

        check_fs unless File.exist?(lockfile_path)
      end

      # HashMethods (mixed in above) defines four methods that must be
      # overridden. The default implementations simply raise
      # NotImplementedError. The four methods are: [], []=, delete, and each.

      def close
        # No-op, should probably be overridden
      end

      def uid
        # No-op, should probably be overridden
      end

      def check_fs
        warn_flock unless flock_works?
      end

      def flock_works?
        flock_works = false
        ensure_path_exists(path)
        lockfile = Tempfile.new(['flock_works.', '.lock'], path)
        begin
          lockfile.close
          File.open(lockfile.path) do |outer|
            outer.flock(File::LOCK_EX)
            File.open(lockfile.path) do |inner|
              flock_works = inner.flock(File::LOCK_EX | File::LOCK_NB) == false
            end
          end
        rescue
        ensure
          lockfile.unlink
        end
        flock_works
      end

      protected

      def ensure_path_exists(path)
        FileUtils.mkdir_p(path) unless File.directory?(path)
      end

      def lock_for_write
        ensure_path_exists(path)
        File.open(lockfile_path, File::CREAT) do |lockfile|
          lockfile.flock(File::LOCK_EX)
          yield
        end
      end

      def lock_for_read
        ensure_path_exists(path)
        File.open(lockfile_path, File::CREAT) do |lockfile|
          lockfile.flock(File::LOCK_SH)
          yield
        end
      end

      def warn(message)
        Kernel.warn "\e[31m#{self.class}: Warning: #{message}\e[0m"
      end

      private

      def lockfile_path
        File.join(path, 'hammerspace.lock')
      end

      def warn_flock
        warn "filesystem does not appear to support flock(2). " \
             "Concurrent access may not behave as expected."
      end

    end

  end
end

# Require all backends
Dir[File.expand_path("../backend/*.rb", __FILE__)].each { |f| require f }
