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

  it "supports enumerable" do
    hash = Hammerspace::Hash.new(path, options)
    hash['a'] = 'A'
    hash['b'] = 'B'
    result = hash.map { |key,value| key + value }
    result.should == ['aA', 'bB']
  end

end
