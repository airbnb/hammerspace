require 'spec_helper'

describe Hammerspace do

  let(:path) { HAMMERSPACE_ROOT }
  let(:options) { {} }

  describe "#initialize" do

    it "returns a Hammerspace::Hash object" do
      hash = Hammerspace.new(path, options)
      hash.should be_an_instance_of(Hammerspace::Hash)
    end

    it "takes a third argument and sets default" do
      hash = Hammerspace.new(path, options, 'default')
      hash.default.should == 'default'
    end

    it "takes a block and sets default_proc" do
      hash = Hammerspace::Hash.new(path, options) { |h,k| k }
      hash.default_proc.should be_an_instance_of(Proc)
    end

  end

end
