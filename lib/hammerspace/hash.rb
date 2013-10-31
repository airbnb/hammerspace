require 'forwardable'

module Hammerspace

  class Hash
    extend Forwardable
    include Enumerable

    attr_reader :path
    attr_reader :options
    attr_reader :backend
    attr_reader :default_proc

    # TODO: include more methods that ruby's Hash supports
    def_delegators :backend,
      :[],
      :[]=,
      :clear,
      :close,
      :delete,
      :each,
      :empty?,
      :fetch,
      :flatten,
      :has_key?,
      :has_value?,
      :merge!,
      :key,
      :keys,
      :replace,
      :size,
      :to_a,
      :to_hash,
      :values,
      :values_at

    alias_method :store, :[]=
    alias_method :each_pair, :each
    alias_method :key?, :has_key?
    alias_method :include?, :has_key?
    alias_method :member?, :has_key?
    alias_method :value?, :has_value?
    alias_method :update, :merge!
    alias_method :initialize_copy, :replace
    alias_method :length, :size

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
