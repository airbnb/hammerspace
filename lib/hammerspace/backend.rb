require 'fileutils'
require 'tempfile'

module Hammerspace
  module Backend

    class Base

      attr_reader :path
      attr_reader :options

      def initialize(path, options={})
        @path    = path
        @options = options

        check_fs unless File.exist?(lockfile_path)
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
        FileUtils.mkdir_p(path)
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

      private

      def lockfile_path
        File.join(path, 'hammerspace.lock')
      end

      def warn_flock
        warn "#{self.class}: Warning: filesystem does not appear to support flock(2). " \
             "Concurrent access may not behave as expected.".red
      end

    end

  end
end

# Require all backends
Dir[File.expand_path("../backend/*.rb", __FILE__)].each { |f| require f }
