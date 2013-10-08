require 'spec_helper'

describe Hammerspace::Hash do

  let(:path) { 'tmp' }
  let(:options) { {} }

  before do
    FileUtils.rm_rf(path, :secure => true)
  end

  after(:all) do
    FileUtils.rm_rf(path, :secure => true)
  end

  it "creates the backend" do
    hash = Hammerspace::Hash.new(path)
    hash.close

    hash.backend.should be_a_kind_of(Hammerspace::Backend::Base)
  end

  it "takes a block" do
    hash = nil
    Hammerspace::Hash.new(path) { |h| hash = h }

    hash.should be_an_instance_of(Hammerspace::Hash)
  end

  it "calls close when given a block" do
    Hammerspace::Hash.any_instance.should_receive(:close).once.and_call_original
    Hammerspace::Hash.new(path) {}
  end

  it "supports enumerable" do
    hash = Hammerspace::Hash.new(path, options)
    hash['a'] = 'A'
    hash['b'] = 'B'
    result = hash.map { |key,value| key + value }
    result.should == ['aA', 'bB']
  end

end
