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

      describe "#==" do

        it "returns false if different sizes" do
          h1 = Hammerspace.new(File.join(path, '1'), options)
          h1['a'] = 'A'
          h1['b'] = 'B'

          h2 = Hammerspace.new(File.join(path, '2'), options)
          h2['a'] = 'A'

          h1.should_not == h2

          h1.close
          h2.close
        end

        it "does not consider default values" do
          h1 = Hammerspace.new(File.join(path, '1'), options)
          h1['a'] = 'A'
          h1['b'] = 'B'

          h2 = Hammerspace.new(File.join(path, '2'), options, 'B')
          h2['a'] = 'A'

          h1.should_not == h2

          h1.close
          h2.close
        end

        it "returns false if different keys" do
          h1 = Hammerspace.new(File.join(path, '1'), options)
          h1['a'] = 'A'
          h1['b'] = 'B'

          h2 = Hammerspace.new(File.join(path, '2'), options)
          h2['a'] = 'A'
          h2['B'] = 'B'

          h1.should_not == h2

          h1.close
          h2.close
        end

        it "returns false if different values" do
          h1 = Hammerspace.new(File.join(path, '1'), options)
          h1['a'] = 'A'
          h1['b'] = 'B'

          h2 = Hammerspace.new(File.join(path, '2'), options)
          h2['a'] = 'A'
          h2['b'] = 'b'

          h1.should_not == h2

          h1.close
          h2.close
        end

        it "returns true if same keys and values" do
          h1 = Hammerspace.new(File.join(path, '1'), options)
          h1['a'] = 'A'
          h1['b'] = 'B'

          h2 = Hammerspace.new(File.join(path, '2'), options)
          h2['a'] = 'A'
          h2['b'] = 'B'

          h1.should == h2

          h1.close
          h2.close
        end

        it "works with hashes" do
          hash = Hammerspace.new(File.join(path, '1'), options)
          hash['a'] = 'A'
          hash['b'] = 'B'
          hash.should == {'a' => 'A', 'b' => 'B'}
          hash.close
        end

      end

      describe "#[]" do

        it "returns value if key exists" do
          hash = Hammerspace.new(path, options)
          hash.default = 'default'
          hash['foo'] = 'bar'
          hash['foo'].should == 'bar'
          hash.close
        end

        it "returns default value if key does not exist" do
          hash = Hammerspace.new(path, options)
          hash.default = 'default'
          hash['foo'].should == 'default'
          hash.close
        end

        it "supports storing the default value" do
          hash = Hammerspace.new(path, options) { |h,k| h[k] = 'Go fish' }
          hash['foo'].should == 'Go fish'
          hash.has_key?('foo').should be_true
          hash.close
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
          hash.close
        end

      end

      describe "#assoc" do

        it "returns key value pair when key is present" do
          hash = Hammerspace.new(path, options)
          hash['foo'] = 'bar'
          hash.assoc('foo').should == ['foo', 'bar']
          hash.close
        end

        it "returns nil when key is not present" do
          hash = Hammerspace.new(path, options)
          hash['foo'] = 'bar'
          hash.assoc('otherkey').should be_nil
          hash.close
        end

        it "returns nil when empty" do
          hash = Hammerspace.new(path, options)
          hash.assoc('foo').should be_nil
          hash.close
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

        it "returns the hash" do
          hash = Hammerspace.new(path, options)
          hash.clear.should == hash
          hash.close
        end

      end

      describe "#delete" do

        it "deletes" do
          hash = Hammerspace.new(path, options)
          hash['foo'] = 'bar'
          hash.delete('foo')
          hash.key?('foo').should be_false
          hash['foo'].should be_nil
          hash.close
        end

      end

      describe "#delete_if" do

        let(:hash) do
          h = Hammerspace.new(path, options)
          h['a'] = 'A'
          h['b'] = 'B'
          h
        end

        context "with block" do

          it "deletes when true" do
            hash.delete_if { |key,value| key == 'a' }
            hash.key?('a').should be_false
            hash['a'].should be_nil
            hash.key?('b').should be_true
            hash['b'].should == 'B'
            hash.close
          end

          it "returns the hash" do
            hash.delete_if { |key,value| true }.should == hash
            hash.close
          end

        end

        context "with enumerator" do

          it "deletes when true" do
            hash.delete_if.each { |key,value| key == 'a' }
            hash.key?('a').should be_false
            hash['a'].should be_nil
            hash.key?('b').should be_true
            hash['b'].should == 'B'
            hash.close
          end

        end

      end

      describe "#each" do

        let(:keys)   { [] }
        let(:values) { [] }
        let(:hash) do
          h = Hammerspace.new(path, options)
          h['a'] = 'A'
          h['b'] = 'B'
          h
        end

        context "with block" do

          it "allows iteration" do
            hash.each do |key,value|
              keys << key
              values << value
            end
            hash.close

            keys.should == ['a', 'b']
            values.should == ['A', 'B']
          end

          it "allows iteration when empty" do
            iterations = 0

            hash = Hammerspace.new(path, options)
            hash.each { |key,value| iterations += 1 }
            hash.close

            iterations.should == 0
          end

          it "allows updating during iteration" do
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

          it "allows updating and reading during iteration" do
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

          it "isolates iterators during iteration" do
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

        end

        context "with enumerator" do

          it "allows iteration" do
            hash.each.each do |key,value|
              keys << key
              values << value
            end
            hash.close

            keys.should == ['a', 'b']
            values.should == ['A', 'B']
          end

          it "allows iteration when empty" do
            iterations = 0

            hash = Hammerspace.new(path, options)
            hash.each.each { |key,value| iterations += 1 }
            hash.close

            iterations.should == 0
          end

          it "allows updating during iteration" do
            hash.each.each do |key,value|
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

          it "allows updating and reading during iteration" do
            hash.each.each do |key,value|
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

          it "isolates iterators during iteration" do
            hash.each.each do |key,value|
              hash['b'] = 'C'
              keys << key
              values << value
            end

            keys.should == ['a', 'b']
            values.should == ['A', 'B']

            hash['b'].should == 'C'

            hash.close
          end

          it "returns the hash" do
            hash.each { |key,value| 'foo' }.should == hash
          end

        end

      end

      describe "#each_key" do

        let(:keys)   { [] }
        let(:hash) do
          h = Hammerspace.new(path, options)
          h['a'] = 'A'
          h['b'] = 'B'
          h
        end

        context "with block" do

          it "allows iteration" do
            hash.each_key do |key|
              keys << key
            end
            hash.close

            keys.should == ['a', 'b']
          end

          it "allows iteration when empty" do
            iterations = 0

            hash = Hammerspace.new(path, options)
            hash.each_key { |key| iterations += 1 }
            hash.close

            iterations.should == 0
          end

          it "allows updating during iteration" do
            hash.each_key do |key|
              keys << key
              hash[key] = 'C'
            end

            keys.should == ['a', 'b']

            hash['a'].should == 'C'
            hash['b'].should == 'C'

            hash.close
          end

          it "allows updating and reading during iteration" do
            hash.each_key do |key|
              keys << key
              hash[key] = 'C'
              hash[key].should == 'C'
            end

            keys.should == ['a', 'b']

            hash['a'].should == 'C'
            hash['b'].should == 'C'

            hash.close
          end

          it "isolates iterators during iteration" do
            hash.each_key do |key|
              hash['b'] = 'C'
              keys << key
            end

            keys.should == ['a', 'b']

            hash['b'].should == 'C'

            hash.close
          end

          it "returns the hash" do
            hash.each_key { |key| 'foo' }.should == hash
          end

        end

        context "with enumerator" do

          it "allows iteration" do
            hash.each_key.each do |key|
              keys << key
            end
            hash.close

            keys.should == ['a', 'b']
          end

          it "allows iteration when empty" do
            iterations = 0

            hash = Hammerspace.new(path, options)
            hash.each_key.each { |key,value| iterations += 1 }
            hash.close

            iterations.should == 0
          end

          it "allows updating during iteration" do
            hash.each_key.each do |key|
              keys << key
              hash[key] = 'C'
            end

            keys.should == ['a', 'b']

            hash['a'].should == 'C'
            hash['b'].should == 'C'

            hash.close
          end

          it "allows updating and reading during iteration" do
            hash.each_key.each do |key|
              keys << key
              hash[key] = 'C'
              hash[key].should == 'C'
            end

            keys.should == ['a', 'b']

            hash['a'].should == 'C'
            hash['b'].should == 'C'

            hash.close
          end

          it "isolates iterators during iteration" do
            hash.each_key.each do |key|
              hash['b'] = 'C'
              keys << key
            end

            keys.should == ['a', 'b']

            hash['b'].should == 'C'

            hash.close
          end

        end

      end

      describe "#each_value" do

        let(:values) { [] }
        let(:hash) do
          h = Hammerspace.new(path, options)
          h['a'] = 'A'
          h['b'] = 'B'
          h
        end

        context "with block" do

          it "allows iteration" do
            hash.each_value do |value|
              values << value
            end
            hash.close

            values.should == ['A', 'B']
          end

          it "allows iteration when empty" do
            iterations = 0

            hash = Hammerspace.new(path, options)
            hash.each_value { |value| iterations += 1 }
            hash.close

            iterations.should == 0
          end

          it "allows updating during iteration" do
            hash.each_value do |value|
              values << value
              hash['a'] = 'C'
            end

            values.should == ['A', 'B']

            hash['a'].should == 'C'

            hash.close
          end

          it "allows updating and reading during iteration" do
            hash.each_value do |value|
              values << value
              hash['a'] = 'C'
              hash['a'].should == 'C'
            end

            values.should == ['A', 'B']

            hash['a'].should == 'C'

            hash.close
          end

          it "isolates iterators during iteration" do
            hash.each_value do |value|
              hash['b'] = 'C'
              values << value
            end

            values.should == ['A', 'B']

            hash['b'].should == 'C'

            hash.close
          end

          it "returns the hash" do
            hash.each_value { |value| 'foo' }.should == hash
          end

        end

        context "with enumerator" do

          it "allows iteration" do
            hash.each_value.each do |value|
              values << value
            end
            hash.close

            values.should == ['A', 'B']
          end

          it "allows iteration when empty" do
            iterations = 0

            hash = Hammerspace.new(path, options)
            hash.each_value.each { |value| iterations += 1 }
            hash.close

            iterations.should == 0
          end

          it "allows updating during iteration" do
            hash.each_value.each do |value|
              values << value
              hash['a'] = 'C'
            end

            values.should == ['A', 'B']

            hash['a'].should == 'C'

            hash.close
          end

          it "allows updating and reading during iteration" do
            hash.each_value.each do |value|
              values << value
              hash['a'] = 'C'
              hash['a'].should == 'C'
            end

            values.should == ['A', 'B']

            hash['a'].should == 'C'

            hash.close
          end

          it "isolates iterators during iteration" do
            hash.each_value.each do |value|
              hash['b'] = 'C'
              values << value
            end

            values.should == ['A', 'B']

            hash['b'].should == 'C'

            hash.close
          end

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

      describe "#eql?" do

        it "returns false if different sizes" do
          h1 = Hammerspace.new(File.join(path, '1'), options)
          h1['a'] = 'A'
          h1['b'] = 'B'

          h2 = Hammerspace.new(File.join(path, '2'), options)
          h2['a'] = 'A'

          h1.should_not eql(h2)

          h1.close
          h2.close
        end

        it "does not consider default values" do
          h1 = Hammerspace.new(File.join(path, '1'), options)
          h1['a'] = 'A'
          h1['b'] = 'B'

          h2 = Hammerspace.new(File.join(path, '2'), options, 'B')
          h2['a'] = 'A'

          h1.should_not eql(h2)

          h1.close
          h2.close
        end

        it "returns false if different keys" do
          h1 = Hammerspace.new(File.join(path, '1'), options)
          h1['a'] = 'A'
          h1['b'] = 'B'

          h2 = Hammerspace.new(File.join(path, '2'), options)
          h2['a'] = 'A'
          h2['B'] = 'B'

          h1.should_not eql(h2)

          h1.close
          h2.close
        end

        it "returns false if different values" do
          h1 = Hammerspace.new(File.join(path, '1'), options)
          h1['a'] = 'A'
          h1['b'] = 'B'

          h2 = Hammerspace.new(File.join(path, '2'), options)
          h2['a'] = 'A'
          h2['b'] = 'b'

          h1.should_not eql(h2)

          h1.close
          h2.close
        end

        it "returns true if same keys and values" do
          h1 = Hammerspace.new(File.join(path, '1'), options)
          h1['a'] = 'A'
          h1['b'] = 'B'

          h2 = Hammerspace.new(File.join(path, '2'), options)
          h2['a'] = 'A'
          h2['b'] = 'B'

          h1.should eql(h2)

          h1.close
          h2.close
        end

        it "works with hashes" do
          hash = Hammerspace.new(File.join(path, '1'), options)
          hash['a'] = 'A'
          hash['b'] = 'B'
          hash.should eql({'a' => 'A', 'b' => 'B'})
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

      describe "#keep_if" do

        let(:hash) do
          h = Hammerspace.new(path, options)
          h['a'] = 'A'
          h['b'] = 'B'
          h
        end

        context "with block" do

          it "keeps when true" do
            hash.keep_if { |key,value| key == 'b' }
            hash.key?('a').should be_false
            hash['a'].should be_nil
            hash.key?('b').should be_true
            hash['b'].should == 'B'
            hash.close
          end

          it "returns the hash" do
            hash.keep_if { |key,value| true }.should == hash
            hash.close
          end

        end

        context "with enumerator" do

          it "keeps when true" do
            hash.keep_if.each { |key,value| key == 'b' }
            hash.key?('a').should be_false
            hash['a'].should be_nil
            hash.key?('b').should be_true
            hash['b'].should == 'B'
            hash.close
          end

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

        it "returns the hash" do
          hash = Hammerspace.new(path, options)
          hash.merge!({}).should == hash
          hash.close
        end

      end

      describe "#rassoc" do

        it "returns key value pair when value is present" do
          hash = Hammerspace.new(path, options)
          hash['foo'] = 'bar'
          hash.rassoc('bar').should == ['foo', 'bar']
          hash.close
        end

        it "returns first key value pair when value is present multiple times" do
          hash = Hammerspace.new(path, options)
          hash['foo'] = 'bar'
          hash['otherkey'] = 'bar'
          hash.rassoc('bar').should == ['foo', 'bar']
          hash.close
        end

        it "returns nil when value is not present" do
          hash = Hammerspace.new(path, options)
          hash['foo'] = 'bar'
          hash.rassoc('otherkey').should be_nil
          hash.close
        end

        it "returns nil when empty" do
          hash = Hammerspace.new(path, options)
          hash.rassoc('foo').should be_nil
          hash.close
        end

      end

      describe "#reject!" do

        let(:hash) do
          h = Hammerspace.new(path, options)
          h['a'] = 'A'
          h['b'] = 'B'
          h
        end

        context "with block" do

          it "deletes when true" do
            hash.reject! { |key,value| key == 'a' }
            hash.key?('a').should be_false
            hash['a'].should be_nil
            hash.key?('b').should be_true
            hash['b'].should == 'B'
            hash.close
          end

          it "returns the hash if items deleted" do
            hash.reject! { |key,value| true }.should == hash
            hash.close
          end

          it "returns nil if no items deleted" do
            hash.reject! { |key,value| false }.should be_nil
            hash.close
          end

        end

        context "with enumerator" do

          it "deletes when true" do
            hash.reject!.each { |key,value| key == 'a' }
            hash.key?('a').should be_false
            hash['a'].should be_nil
            hash.key?('b').should be_true
            hash['b'].should == 'B'
            hash.close
          end

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

        it "returns the hash" do
          hash = Hammerspace.new(path, options)
          hash.replace({}).should == hash
          hash.close
        end

      end

      describe "#select!" do

        let(:hash) do
          h = Hammerspace.new(path, options)
          h['a'] = 'A'
          h['b'] = 'B'
          h
        end

        context "with block" do

          it "keeps when true" do
            hash.select! { |key,value| key == 'b' }
            hash.key?('a').should be_false
            hash['a'].should be_nil
            hash.key?('b').should be_true
            hash['b'].should == 'B'
            hash.close
          end

          it "returns the hash if items deleted" do
            hash.select! { |key,value| false }.should == hash
            hash.close
          end

          it "returns nil if no items deleted" do
            hash.select! { |key,value| true }.should be_nil
            hash.close
          end

        end

        context "with enumerator" do

          it "keeps when true" do
            hash.select!.each { |key,value| key == 'b' }
            hash.key?('a').should be_false
            hash['a'].should be_nil
            hash.key?('b').should be_true
            hash['b'].should == 'B'
            hash.close
          end

        end

      end

      describe "#shift" do

        it "removes and returns the first key value pair" do
          hash = Hammerspace.new(path, options)
          hash['a'] = 'A'
          hash['b'] = 'B'
          hash.shift.should == ['a', 'A']
          hash.keys.should == ['b']
          hash.values.should == ['B']
          hash.close
        end

        it "returns the default value if empty" do
          hash = Hammerspace.new(path, options, 'default')
          hash.shift.should == 'default'
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
