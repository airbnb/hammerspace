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

      it "supports multiple writers" do
        writer1 = Hammerspace.new(path, options)
        writer1['foo'] = 'one'

        writer2 = Hammerspace.new(path, options)
        writer2['foo'] = 'two'
        writer2['bar'] = 'two' # test works even without locking if this isn't here?

        writer2.close
        writer1.close # last write wins

        hash = Hammerspace.new(path, options)
        hash['foo'].should == 'one'
        hash['bar'].should be_nil
        hash.close
      end

      it "supports multiple appenders" do
        hash = Hammerspace.new(path, options)
        hash['foo'] = 'bar'
        hash.close

        writer1 = Hammerspace.new(path, options)
        writer1['foo'] = 'one'

        writer2 = Hammerspace.new(path, options)
        writer2['foo'] = 'two'
        writer2['bar'] = 'two' # test works even without locking if this isn't here?

        writer2.close
        writer1.close # last write wins

        hash = Hammerspace.new(path, options)
        hash['foo'].should == 'one'
        hash['bar'].should be_nil
        hash.close
      end

      it "handles high write concurrency" do
        run_write_concurrency_test(path, options)
      end

      describe "#[]" do

        it "returns value if key exists" do
          hash = Hammerspace.new(path, options)
          hash.default = 'default'
          hash['foo'] = 'bar'
          hash['foo'].should == 'bar'
        end

        it "returns default value if key does not exist" do
          hash = Hammerspace.new(path, options)
          hash.default = 'default'
          hash['foo'].should == 'default'
        end

        it "supports storing the default value" do
          hash = Hammerspace.new(path, options) { |h,k| h[k] = 'Go fish' }
          hash['foo'].should == 'Go fish'
          hash.include?('foo').should be_true
        end

      end

      describe "#[]=" do

        it "handles key mutation" do
          hash = Hammerspace.new(path, options)
          key = 'foo'
          hash[key] = 'bar'
          key = 'key'
          hash['foo'].should == 'bar'
          hash['key'].should be_nil
        end

      end

      describe "#clear" do

        it "removes all keys and values" do
          hash = Hammerspace.new(path, options)
          hash['foo'] = 'bar'
          hash.close

          hash = Hammerspace.new(path, options)
          hash.clear
          hash['foo'].should be_nil
          hash.size.should == 0
          hash.close
        end

        it "removes unflushed keys and values" do
          hash = Hammerspace.new(path, options)
          hash['foo'] = 'bar'
          hash.clear
          hash['foo'].should be_nil
          hash.size.should == 0
          hash.close
        end

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

        it "allows updating and reading during iteration with block" do
          keys = []
          values = []

          hash = Hammerspace.new(path, options)
          hash['a'] = 'A'
          hash['b'] = 'B'
          hash.each do |key,value|
            keys << key
            values << value
            hash[key] = 'C'
            hash[key].should == 'C'
          end

          keys.should == ['a', 'b']
          values.should == ['A', 'B']

          hash['a'].should == 'C'
          hash['b'].should == 'C'

          hash.close
        end

        it "allows updating and reading during iteration with enumerator" do
          keys = []
          values = []

          hash = Hammerspace.new(path, options)
          hash['a'] = 'A'
          hash['b'] = 'B'
          hash.each.map do |key,value|
            keys << key
            values << value
            hash[key] = 'C'
            hash[key].should == 'C'
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

      describe "#fetch" do

        it "returns value if key exists" do
          hash = Hammerspace.new(path, options)
          hash['foo'] = 'bar'
          hash.fetch('foo').should == 'bar'
        end

        it "calls block to determine value if key does not exist" do
          hash = Hammerspace.new(path, options)
          hash.fetch('foo') { |key| "block#{key}" }.should == "blockfoo"
          hash.close
        end

        it "returns default value if key does not exist" do
          hash = Hammerspace.new(path, options)
          hash.fetch('foo', 'default').should == 'default'
          hash.close
        end

        it "calls block to determine value if key does not exist and both second argument and block are passed" do
          hash = Hammerspace.new(path, options)
          hash.fetch('foo', 'default') { |key| "block#{key}" }.should == "blockfoo"
          hash.close
        end

        it "raises KeyError if key does not exist" do
          hash = Hammerspace.new(path, options)
          expect {
            hash.fetch('foo')
          }.to raise_error(KeyError)
          hash.close
        end

        it "raises ArgumentError if a third argument is passed" do
          hash = Hammerspace.new(path, options)
          expect {
            hash.fetch('foo', 'default', 'bogus')
          }.to raise_error(ArgumentError)
          hash.close
        end

      end

      describe "#flatten" do

        it "returns an array of key value pairs" do
          hash = Hammerspace.new(path, options)
          hash['a'] = 'A'
          hash['b'] = 'B'
          hash.flatten.should == ['a', 'A', 'b', 'B']
          hash.close
        end

        it "returns an empty array when empty" do
          hash = Hammerspace.new(path, options)
          hash.flatten.should == []
          hash.close
        end

        it "accepts an optional level argument" do
          hash = Hammerspace.new(path, options)
          hash['a'] = 'A'
          hash['b'] = 'B'
          hash.flatten(2).should == ['a', 'A', 'b', 'B']
          hash.close
        end

        it "raises ArgumentError if a second argument is passed" do
          hash = Hammerspace.new(path, options)
          expect {
            hash.flatten(1, 'bogus')
          }.to raise_error(ArgumentError)
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

      describe "#key" do

        it "returns value if key exists" do
          hash = Hammerspace.new(path, options)
          hash['foo'] = 'bar'
          hash.key('foo').should == 'bar'
        end

        it "returns nil if key does not exist" do
          hash = Hammerspace.new(path, options)
          hash.key('foo').should be_nil
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

      describe "#merge!" do

        it "adds new values" do
          hash = Hammerspace.new(path, options)
          hash.merge!({'foo' => 'bar'})
          hash['foo'].should == 'bar'
          hash.close
        end

        it "updates existing values" do
          hash = Hammerspace.new(path, options)
          hash['foo'] = 'bar'
          hash.merge!({'foo' => 'newvalue'})
          hash['foo'].should == 'newvalue'
          hash.close
        end

        it "calls block to determine value on duplicates" do
          hash = Hammerspace.new(path, options)
          hash['foo'] = 'bar'
          hash.merge!({'foo' => 'newvalue'}) { |key, v1, v2| v1 + v2 }
          hash['foo'].should == 'barnewvalue'
          hash.close
        end

      end

      describe "#replace" do

        it "removes values" do
          hash = Hammerspace.new(path, options)
          hash['a'] = 'A'
          hash.close

          hash.replace({'b' => 'B'})
          hash['a'].should be_nil
          hash['b'].should == 'B'
          hash.close
        end

        it "updates existing values" do
          hash = Hammerspace.new(path, options)
          hash['foo'] = 'bar'
          hash.close

          hash.replace({'foo' => 'newvalue'})
          hash['foo'].should == 'newvalue'
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

      describe "#to_a" do

        it "returns an array of key value pairs" do
          hash = Hammerspace.new(path, options)
          hash['a'] = 'A'
          hash['b'] = 'B'
          hash.to_a.should == [['a', 'A'], ['b', 'B']]
          hash.close
        end

        it "returns an empty array when empty" do
          hash = Hammerspace.new(path, options)
          hash.to_a.should == []
          hash.close
        end

      end

      describe "#to_hash" do

        it "returns a hash" do
          hash = Hammerspace.new(path, options)
          hash['a'] = 'A'
          hash['b'] = 'B'
          hash.to_hash.should == {'a' => 'A', 'b' => 'B'}
          hash.close
        end

        it "returns an empty hash when empty" do
          hash = Hammerspace.new(path, options)
          hash.to_hash.should == {}
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

      describe "#values_at" do

        it "returns values" do
          hash = Hammerspace.new(path, options)
          hash['a'] = 'A'
          hash['b'] = 'B'
          hash.values_at('b', 'a').should == ['B', 'A']
          hash.close
        end

        it "returns default values when keys do not exist" do
          hash = Hammerspace.new(path, options)
          hash.default = 'default'
          hash['a'] = 'A'
          hash.values_at('a', 'b').should == ['A', 'default']
          hash.close
        end

      end

    end
  end
end
