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

    end

  end
end

# Require all backends
Dir[File.expand_path("../backend/*.rb", __FILE__)].each { |f| require f }
