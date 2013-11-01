module Hammerspace
  module HashMethods

    def [](key)
      raise NotImplementedError
    end

    def []=(key, value)
      raise NotImplementedError
    end

    def clear
      each { |key, value| delete(key) }
      frontend
    end

    def delete(key)
      raise NotImplementedError
    end

    def each(&block)
      raise NotImplementedError
    end

    def each_key(&block)
      if block_given?
        each { |key, value| yield key }
      else
        Enumerator.new { |y| each { |key, value| y << key } }
      end
    end

    def each_value(&block)
      if block_given?
        each { |key, value| yield value }
      else
        Enumerator.new { |y| each { |key, value| y << value } }
      end
    end

    def empty?
      size == 0
    end

    def fetch(key, *args)
      raise ArgumentError, "wrong number of arguments" if args.size > 1

      return self[key] if has_key?(key)

      if block_given?
        yield key
      elsif args.size == 1
        args.first
      else
        raise KeyError, "key not found: \"#{key}\""
      end
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
      !!frontend.find { |k,v| k.eql?(key) }
    end

    def has_value?(value)
      !!frontend.find { |k,v| v == value }
    end

    def key(key)
      has_key?(key) ? self[key] : nil
    end

    def keys
      each.map { |key, value| key }
    end

    def merge!(hash)
      hash.each do |key, value|
        if block_given?
          self[key] = yield key, self[key], value
        else
          self[key] = value
        end
      end
      frontend
    end

    def replace(hash)
      clear
      merge!(hash)
    end

    def size
      count = 0
      each { |key, value| count += 1 }
      count
    end

    def to_a
      frontend.each_with_object([]) { |args, array| array << [args.first, args.last] }
    end

    def to_hash
      frontend.each_with_object({}) { |args, hash| hash[args.first] = args.last }
    end

    def values
      each.map { |key, value| value }
    end

    def values_at(*args)
      args.map { |key| self[key] }
    end

  end
end
