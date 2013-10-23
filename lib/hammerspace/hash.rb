require 'forwardable'

module Hammerspace

  class Hash
    extend Forwardable
    include Enumerable

    attr_reader :path
    attr_reader :options

    attr_reader :backend

    # TODO: include more methods that ruby's Hash supports
    def_delegators :backend,
      :[],
      :[]=,
      :clear,
      :close,
      :delete,
      :each,
      :empty?,
      :has_key?,
      :has_value?,
      :merge!,
      :keys,
      :size,
      :values

    alias_method :key?, :has_key?
    alias_method :include?, :has_key?
    alias_method :member?, :has_value?
    alias_method :update, :merge!
    alias_method :length, :size

    DEFAULT_OPTIONS = {
      :backend        => Hammerspace::Backend::Sparkey
    }

    def initialize(path, options={})
      @path    = path
      @options = DEFAULT_OPTIONS.merge(options)

      construct_backend

      if block_given?
        yield self
        close
      end
    end

    private

    def construct_backend
      @backend = options[:backend].new(path, options)
    end

  end

end
