require 'spec_helper'

describe Hammerspace::Backend::Sparkey do

  let(:path) { 'tmp' }
  let(:options) { {} }

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

  it "bulks writes" do
    Gnista::Hash.should_receive(:write).once.and_call_original

    hash = Hammerspace.new(path, options)
    hash['foo'] = 'bar'
    hash['foo'] = 'newvalue'
    hash.close
  end

  it "handles high write concurrency and cleans up" do
    run_write_concurrency_test(path, options)

    # Also, at the end of the test, there should be one directory and one symlink.
    SparkeyDirectoryHelper.directory_count(path).should == 1
    SparkeyDirectoryHelper.has_current_symlink?(path).should be_true
    SparkeyDirectoryHelper.has_unknown_files?(path).should be_false
  end

  describe "#clear" do

    it "removes all keys and values and cleans up" do
      hash = Hammerspace.new(path, options)
      hash['foo'] = 'bar'
      hash.close

      hash = Hammerspace.new(path, options)
      hash.clear
      hash['foo'].should be_nil
      hash.size.should == 0
      hash.close

      SparkeyDirectoryHelper.directory_count(path).should == 0
      SparkeyDirectoryHelper.has_current_symlink?(path).should be_false
    end

    it "removes unflushed keys and values and cleans up" do
      hash = Hammerspace.new(path, options)
      hash['foo'] = 'bar'
      hash.clear
      hash['foo'].should be_nil
      hash.size.should == 0
      hash.close

      SparkeyDirectoryHelper.directory_count(path).should == 0
      SparkeyDirectoryHelper.has_current_symlink?(path).should be_false
    end

  end

  describe "#close" do

    it "removes empty directories" do
      writer1 = Hammerspace.new(path, options)
      writer1['foo'] = 'bar'
      writer1.close

      reader = Hammerspace.new(path, options)
      reader['foo'].should == 'bar'

      writer2 = Hammerspace.new(path, options)
      writer2['foo'] = 'bar'
      writer2.close # cleanup fails since reader has open fds

      SparkeyDirectoryHelper.directory_count(path).should == 2

      reader.close

      SparkeyDirectoryHelper.directory_count(path).should == 1
    end

  end

  describe "#each" do

    it "removes empty directories after iteration with block" do
      writer1 = Hammerspace.new(path, options)
      writer1['foo'] = 'bar'
      writer1.close

      reader = Hammerspace.new(path, options)
      reader.each do |key,value|
        writer2 = Hammerspace.new(path, options)
        writer2['foo'] = 'bar'
        writer2.close # cleanup fails since reader has open fds

        SparkeyDirectoryHelper.directory_count(path).should == 2
      end

      SparkeyDirectoryHelper.directory_count(path).should == 1

      reader.close
    end

    it "removes empty directories after iteration with enumerator" do
      writer1 = Hammerspace.new(path, options)
      writer1['foo'] = 'bar'
      writer1.close

      reader = Hammerspace.new(path, options)
      reader.each.map do |key,value|
        writer2 = Hammerspace.new(path, options)
        writer2['foo'] = 'bar'
        writer2.close # cleanup fails since reader has open fds

        SparkeyDirectoryHelper.directory_count(path).should == 2
      end

      SparkeyDirectoryHelper.directory_count(path).should == 1

      reader.close
    end

  end

end
