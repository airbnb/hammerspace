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

  describe "#initialize" do

    it "creates the backend" do
      hash = Hammerspace::Hash.new(path, options)
      hash.backend.should be_a_kind_of(Hammerspace::Backend::Base)
    end

    it "takes a third argument and sets default" do
      hash = Hammerspace::Hash.new(path, options, 'default')
      hash.default.should == 'default'
    end

    it "takes a block and sets default_proc" do
      hash = Hammerspace::Hash.new(path, options) { |h,k| k }
      hash.default_proc.should be_an_instance_of(Proc)
    end

    it "raises ArgumentError if both third argument and block are passed" do
      expect {
        Hammerspace::Hash.new(path, options, 'default') { |h,k| k }
      }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError if a fourth argument is passed" do
      expect {
        Hammerspace::Hash.new(path, options, 'default', 'bogus')
      }.to raise_error(ArgumentError)
    end

  end

  describe "#default=" do

    it "sets default" do
      hash = Hammerspace::Hash.new(path, options)
      hash.default = 'bar'
      hash.default.should == 'bar'
    end

    it "unsets default_proc" do
      hash = Hammerspace::Hash.new(path, options)
      hash.default_proc = lambda { |h,k| k }
      hash.default = 'bar'
      hash.default_proc.should be_nil
    end

  end

  describe "#default_proc=" do

    it "sets default_proc" do
      p = lambda { |h,k| k }
      hash = Hammerspace::Hash.new(path, options)
      hash.default_proc = p
      hash.default_proc.should == p
    end

    it "unsets default" do
      hash = Hammerspace::Hash.new(path, options)
      hash.default = 'bar'
      hash.default_proc = p
      hash.default('foo').should be_nil
    end

  end

  describe "#default" do

    context "with default set" do

      context "with an argument" do

        it "returns default value" do
          hash = Hammerspace::Hash.new(path, options)
          hash.default = 'bar'
          hash.default('foo').should == 'bar'
        end

      end

      context "without an argument" do

        it "returns default value" do
          hash = Hammerspace::Hash.new(path, options)
          hash.default = 'bar'
          hash.default('foo').should == 'bar'
        end

      end

    end

    context "with default_proc set" do

      context "with an argument" do

        it "evaluates proc" do
          hash = Hammerspace::Hash.new(path, options) do |h,k|
            h.should == hash
            k.reverse
          end
          hash.default('foo').should == 'oof'
        end

      end

      context "without an argument" do

        it "returns nil" do
          hash = Hammerspace::Hash.new(path, options) { |h,k| k }
          hash.default.should be_nil
        end

      end

    end

  end

  it "supports enumerable" do
    hash = Hammerspace::Hash.new(path, options)
    hash['a'] = 'A'
    hash['b'] = 'B'
    result = hash.map { |key,value| key + value }
    result.should == ['aA', 'bB']
  end

end
