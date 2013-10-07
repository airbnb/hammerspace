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

      it "gets before set" do
        hash = Hammerspace.new(path, options)
        hash['foo'].should be_nil
        hash.close
      end

      it "deletes" do
        hash = Hammerspace.new(path, options)
        hash['foo'] = 'bar'
        hash.delete('foo')
        hash.key?('foo').should be_false
        hash['foo'].should be_nil
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

        it "allows iteration with block when empty" do
          iterations = 0

          hash = Hammerspace.new(path, options)
          hash.each { |key,value| iterations += 1 }
          hash.close

          iterations.should == 0
        end

        it "allows iteration with enumerator when empty" do
          iterations = 0

          hash = Hammerspace.new(path, options)
          hash.each.map { |key,value| iterations += 1 }
          hash.close

          iterations.should == 0
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

      describe "#empty?" do

        it "returns true when empty" do
          hash = Hammerspace.new(path, options)
          hash.empty?.should be_true
          hash.close
        end

        it "returns false when not empty" do
          hash = Hammerspace.new(path, options)
          hash['foo'] = 'bar'
          hash.empty?.should be_false
          hash.close
        end

      end

      describe "#has_key?" do

        it "returns true when key is present" do
          hash = Hammerspace.new(path, options)
          hash['foo'] = 'bar'
          hash.has_key?('foo').should be_true
          hash.close
        end

        it "returns false when key is not present" do
          hash = Hammerspace.new(path, options)
          hash['foo'] = 'bar'
          hash.has_key?('otherkey').should be_false
          hash.close
        end

        it "returns false when empty" do
          hash = Hammerspace.new(path, options)
          hash.has_key?('foo').should be_false
          hash.close
        end

      end

      describe "#has_value?" do

        it "returns true when value is present" do
          hash = Hammerspace.new(path, options)
          hash['foo'] = 'bar'
          hash.has_value?('bar').should be_true
          hash.close
        end

        it "returns false when value is not present" do
          hash = Hammerspace.new(path, options)
          hash['foo'] = 'bar'
          hash.has_value?('othervalue').should be_false
          hash.close
        end

        it "returns false when empty" do
          hash = Hammerspace.new(path, options)
          hash.has_value?('foo').should be_false
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

        it "returns empty array when empty" do
          hash = Hammerspace.new(path, options)
          hash.keys.should == []
          hash.close
        end

      end

      describe "#size" do

        it "returns size" do
          hash = Hammerspace.new(path, options)
          hash['a'] = 'A'
          hash['b'] = 'B'
          hash.size.should == 2
          hash.close
        end

        it "returns 0 when empty" do
          hash = Hammerspace.new(path, options)
          hash.size.should == 0
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

        it "returns empty array when empty" do
          hash = Hammerspace.new(path, options)
          hash.values.should == []
          hash.close
        end

      end

    end
  end
end
