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

  it "supports interleaved gets and sets" do
    hash = Hammerspace.new(path, options)
    hash['foo'] = 'bar'
    hash['foo'].should == 'bar'
    hash['foo'] = 'newvalue'
    hash['foo'].should == 'newvalue'
    hash.close
  end

  it "bulks writes" do
    Gnista::Hash.should_receive(:write).once.and_call_original

    hash = Hammerspace.new(path, options)
    hash['foo'] = 'bar'
    hash['foo'] = 'newvalue'
    hash.close
  end

  it "persists values after reopen" do
    hash = Hammerspace.new(path, options)
    hash['foo'] = 'bar'
    hash.close

    hash = Hammerspace.new(path, options)
    hash['foo'].should == 'bar'
    hash.close
  end

  it "allows updating after reopen" do
    hash = Hammerspace.new(path, options)
    hash['foo'] = 'bar'
    hash.close

    hash = Hammerspace.new(path, options)
    hash['foo'] = 'newvalue'
    hash['foo'].should == 'newvalue'
    hash.close
  end

  it "supports multiple readers" do
    hash = Hammerspace.new(path, options)
    hash['foo'] = 'bar'
    hash.close

    reader1 = Hammerspace.new(path, options)
    reader1['foo'].should == 'bar'

    reader2 = Hammerspace.new(path, options)
    reader2['foo'].should == 'bar'

    reader1.close
    reader2.close
  end

  it "isolates readers" do
    hash = Hammerspace.new(path, options)
    hash['foo'] = 'bar'
    hash.close

    reader1 = Hammerspace.new(path, options)
    reader1['foo'].should == 'bar'

    hash = Hammerspace.new(path, options)
    hash['foo'] = 'newvalue'
    hash.close

    reader1['foo'].should == 'bar' # still 'bar'

    reader2 = Hammerspace.new(path, options)
    reader2['foo'].should == 'newvalue'

    reader1.close
    reader2.close
  end

end
