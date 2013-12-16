module Hammerspace

  # Basic implementations of most methods supported by Ruby's hash
  #
  # Analogous to Enumerable. Mixed into Hammerspace::Backend::Base. A backend
  # need only implement four of these methods: [], []=, delete, and each. (A
  # backend should also implement close and uid, but these are not hash
  # methods; they are hammerspace-specific.) However, a backend may choose to
  # override some of the default implementations if the backend is able to
  # implement the methods more efficiently.
  module HashMethods

    def ==(hash)
      return false if size != hash.size
      each do |key, value|
        return false unless hash.has_key?(key)
        return false unless hash[key] == value
      end
      true
    end

    def [](key)
      raise NotImplementedError
    end

    def []=(key, value)
      raise NotImplementedError
    end

    def assoc(key)
      find { |k,v| k == key }
    end

    def clear
      each { |key, value| delete(key) }
      close # flush immediately
      frontend
    end

    def delete(key)
      raise NotImplementedError
    end

    def delete_if(&block)
      if block_given?
        reject!(&block)
        frontend
      else
        reject!
      end
    end

    def each(&block)
      raise NotImplementedError
    end

    def each_key
      if block_given?
        each { |key, value| yield key }
      else
        Enumerator.new { |y| each { |key, value| y << key } }
      end
    end

    def each_value
      if block_given?
        each { |key, value| yield value }
      else
        Enumerator.new { |y| each { |key, value| y << value } }
      end
    end

    def empty?
      size == 0
    end

    def eql?(hash)
      return false if size != hash.size
      each do |key, value|
        return false unless hash.has_key?(key)
        return false unless hash[key].eql?(value)
      end
      true
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

      each_with_object([]) do |args, array|
        array << args.first
        array << args.last
      end
    end

    def has_key?(key)
      !!find { |k,v| k.eql?(key) }
    end

    def has_value?(value)
      !!find { |k,v| v == value }
    end

    def keep_if(&block)
      if block_given?
        select!(&block)
        frontend
      else
        select!
      end
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

    def rassoc(value)
      find { |k,v| v == value }
    end

    def reject!
      if block_given?
        any_deleted = false
        each do |key, value|
          if yield key, value
            any_deleted = true
            delete(key)
          end
        end
        any_deleted ? frontend : nil
      else
        Enumerator.new do |y|
          each { |key, value| delete(key) if y.yield(key, value) }
        end
      end
    end

    def replace(hash)
      clear
      merge!(hash)
    end

    def select!
      if block_given?
        any_deleted = false
        each do |key, value|
          unless yield key, value
            any_deleted = true
            delete(key)
          end
        end
        any_deleted ? frontend : nil
      else
        Enumerator.new do |y|
          each { |key, value| delete(key) unless y.yield(key, value) }
        end
      end
    end

    def shift
      items = take(1)
      if items.empty?
        frontend.default
      else
        pair = items.first
        delete(pair.first)
        pair
      end
    end

    def size
      count = 0
      each { |key, value| count += 1 }
      count
    end

    def to_hash
      each_with_object({}) { |args, hash| hash[args.first] = args.last }
    end

    def values
      each.map { |key, value| value }
    end

    def values_at(*args)
      args.map { |key| self[key] }
    end

    alias_method :store, :[]=
    alias_method :each_pair, :each
    alias_method :key?, :has_key?

    # alias_method seems to conflict with Enumerable's version of these methods
    def include?(key); has_key?(key); end
    def member?(key); has_key?(key); end

    alias_method :value?, :has_value?
    alias_method :update, :merge!
    alias_method :initialize_copy, :replace
    alias_method :length, :size

  end
end
