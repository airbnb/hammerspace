require 'hammerspace/version'
require 'hammerspace/backend'
require 'hammerspace/hash'

module Hammerspace

  def self.new(path, options={})
    hash = Hash.new(path, options)
    if block_given?
      yield hash
      hash.close
    end
    hash
  end

end
