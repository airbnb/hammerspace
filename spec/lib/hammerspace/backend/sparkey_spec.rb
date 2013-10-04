require 'spec_helper'

describe Hammerspace::Backend::Sparkey do

  let(:path) { 'tmp' }
  let(:options) { { :backend => Hammerspace::Backend::Sparkey } }

  before do
    FileUtils.rm_rf(path, :secure => true)
  end

  after(:all) do
    FileUtils.rm_rf(path, :secure => true)
  end

  it "creates path on set" do
    hash = Hammerspace.new(path, options)
    hash['foo'] = 'bar'
    hash.close

    Dir.exist?(path).should be_true
  end

  it "gets after set" do
    hash = Hammerspace.new(path, options)
    hash['foo'] = 'bar'
    hash['foo'].should == 'bar'
    hash.close
  end

end
