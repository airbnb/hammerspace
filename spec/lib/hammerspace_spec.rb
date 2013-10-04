require 'spec_helper'

describe Hammerspace do

  let(:path) { 'tmp' }

  it "returns a Hammerspace::Hash object" do
    hash = Hammerspace.new(path)
    hash.close

    hash.should be_an_instance_of(Hammerspace::Hash)
  end

  it "takes a block" do
    hash = nil
    Hammerspace.new(path) { |h| hash = h }

    hash.should be_an_instance_of(Hammerspace::Hash)
  end 

end
