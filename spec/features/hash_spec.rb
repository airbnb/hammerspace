require 'spec_helper'

describe Hammerspace do

  [Hammerspace::Backend::Sparkey].each do |backend|
    describe backend do

      let(:path) { 'tmp' }
      let(:options) { { :backend => backend } }

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

      describe "#each" do

        it "allows iteration with block" do
          keys = []
          values = []

          hash = Hammerspace.new(path, options)
          hash['a'] = 'A'
          hash['b'] = 'B'
          hash.each do |key,value|
            keys << key
            values << value
          end
          hash.close

          keys.should == ['a', 'b']
          values.should == ['A', 'B']
        end

        it "allows iteration with enumerator" do
          keys = []
          values = []

          hash = Hammerspace.new(path, options)
          hash['a'] = 'A'
          hash['b'] = 'B'
          hash.each.map do |key,value|
            keys << key
            values << value
          end
          hash.close

          keys.should == ['a', 'b']
          values.should == ['A', 'B']
        end

        it "allows updating during iteration with block" do
          keys = []
          values = []

          hash = Hammerspace.new(path, options)
          hash['a'] = 'A'
          hash['b'] = 'B'
          hash.each do |key,value|
            keys << key
            values << value
            hash[key] = 'C'
          end

          keys.should == ['a', 'b']
          values.should == ['A', 'B']

          hash['a'].should == 'C'
          hash['b'].should == 'C'

          hash.close
        end

        it "allows updating during iteration with enumerator" do
          keys = []
          values = []

          hash = Hammerspace.new(path, options)
          hash['a'] = 'A'
          hash['b'] = 'B'
          hash.each.map do |key,value|
            keys << key
            values << value
            hash[key] = 'C'
          end

          keys.should == ['a', 'b']
          values.should == ['A', 'B']

          hash['a'].should == 'C'
          hash['b'].should == 'C'

          hash.close
        end

        it "isolates iterators during iteration with block" do
          keys = []
          values = []

          hash = Hammerspace.new(path, options)
          hash['a'] = 'A'
          hash['b'] = 'B'
          hash.each do |key,value|
            hash['b'] = 'C'
            keys << key
            values << value
          end

          keys.should == ['a', 'b']
          values.should == ['A', 'B']

          hash['b'].should == 'C'

          hash.close
        end

        it "isolates iterators during iteration with enumerator" do
          keys = []
          values = []

          hash = Hammerspace.new(path, options)
          hash['a'] = 'A'
          hash['b'] = 'B'
          hash.each.map do |key,value|
            hash['b'] = 'C'
            keys << key
            values << value
          end

          keys.should == ['a', 'b']
          values.should == ['A', 'B']

          hash['b'].should == 'C'

          hash.close
        end

      end

      describe "#keys" do

        it "returns keys" do
          hash = Hammerspace.new(path, options)
          hash['a'] = 'A'
          hash['b'] = 'B'
          hash.keys.should == ['a', 'b']
          hash.close
        end

      end

      describe "#values" do

        it "returns values" do
          hash = Hammerspace.new(path, options)
          hash['a'] = 'A'
          hash['b'] = 'B'
          hash.values.should == ['A', 'B']
          hash.close
        end

      end

    end
  end
end
