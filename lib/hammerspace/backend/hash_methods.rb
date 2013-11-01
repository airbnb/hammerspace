module Hammerspace
  module HashMethods

    def [](key)
      raise NotImplementedError
    end

    def []=(key, value)
      raise NotImplementedError
    end

    def clear
      raise NotImplementedError
    end

    def delete(key)
      raise NotImplementedError
    end

    def each(&block)
      raise NotImplementedError
    end

    def empty?
      size == 0
    end

    def fetch(key, *args)
      raise NotImplementedError
    end

    def flatten(*args)
      # Note: the optional level argument is supported for compatibility, but
      # it will never have an effect because only string values are
      # supported.
      raise ArgumentError, "wrong number of arguments" if args.size > 1

      frontend.each_with_object([]) do |args, array|
        array << args.first
        array << args.last
      end
    end

    def has_key?(key)
      raise NotImplementedError
    end

    def has_value?(value)
      !!frontend.find { |k,v| v == value }
    end

    def key(key)
      has_key?(key) ? self[key] : nil
    end

    def keys
      raise NotImplementedError
    end

    def merge!(hash)
      hash.each do |key,value|
        if block_given?
          self[key] = yield key, self[key], value
        else
          self[key] = value
        end
      end

      frontend
    end

    def replace(hash)
      raise NotImplementedError
    end

    def size
      raise NotImplementedError
    end

    def to_a
      frontend.each_with_object([]) { |args, array| array << [args.first, args.last] }
    end

    def to_hash
      frontend.each_with_object({}) { |args, hash| hash[args.first] = args.last }
    end

    def values
      raise NotImplementedError
    end

    def values_at(*args)
      args.map { |key| self[key] }
    end

  end
end
