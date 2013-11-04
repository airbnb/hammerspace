require 'forwardable'

module Hammerspace

  # "Frontend" class
  #
  # All hammerspace functionality is exposed through this class's interface.
  # Responsible for setting up the backend and delegating methods to the
  # backend. Also handles default values. This functionality is designed to be
  # consistent across backends; backends cannot be override this functionality.
  class Hash
    extend Forwardable

    attr_reader :path
    attr_reader :options
    attr_reader :backend
    attr_reader :default_proc

    def_delegators :backend, *Enumerable.instance_methods
    def_delegators :backend, *HashMethods.instance_methods
    def_delegator  :backend, :close

    DEFAULT_OPTIONS = {
      :backend => Hammerspace::Backend::Sparkey
    }

    def initialize(path, options={}, *args, &block)
      raise ArgumentError, "wrong number of arguments" if args.size > 1

      @path    = path
      @options = DEFAULT_OPTIONS.merge(options)
      @backend = @options[:backend].new(self, @path, @options)

      if block_given?
        self.default_proc=(block)
        raise ArgumentError, "wrong number of arguments" if args.size == 1
      else
        self.default=args.first
      end
    end

    def default(*args)
      if @default_proc && args.size
        @default_proc.call(self, args.first)
      else
        @default
      end
    end

    def default=(value)
      @default_proc = nil
      @default = value
    end

    def default_proc=(value)
      @default = nil
      @default_proc = value
    end

  end

end
