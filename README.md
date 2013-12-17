Hammerspace
===========

Hash-like interface to persistent, concurrent, off-heap storage


## What is Hammerspace?

_[Hammerspace](http://en.wikipedia.org/wiki/Hammerspace) ... is a
fan-envisioned extradimensional, instantly accessible storage area in fiction,
which is used to explain how animated, comic, and game characters can produce
objects out of thin air._

This gem provides persistent, concurrently-accessible off-heap storage of
strings with a familiar hash-like interface. It is optimized for bulk writes
and random reads.


## Motivation

Applications often use data that never changes or changes very infrequently. In
many cases, some latency is acceptable when accessing this data. For example, a
user's profile may be loaded from a web service, a database, or an external
shared cache like memcache. In other cases, latency is much more sensitive. For
example, translations may be used many times and incurring even a ~2ms delay to
access them from an external cache would be prohibitively slow.

To work around the performance issue, this type of data is often loaded into
the application at startup. Unfortunately, this means the data is stored on the
heap, where the garbage collector must scan over the objects on every run (at
least in the case of Ruby MRI). Further, for application servers that utilize
multiple processes, each process has its own copy of the data which is an
inefficient use of memory.

Hammerspace solves these problems by moving the data off the heap onto disk.
Leveraging libraries and data structures optimized for bulk writes and random
reads allows an acceptable level of performance to be maintained. Because the
data is persistent, it does not need to be reloaded from an external cache or
service on application startup unless the data has changed.

Unfortunately, these low-level libraries don't always support concurrent
writers. Hammerspace adds concurrency control to allow multiple processes to
update and read from a single shared copy of the data safely. Finally,
hammerspace's interface is designed to mimic Ruby's `Hash` to make integrating
with existing applications simple and straightforward. Different low-level
libraries can be used by implementing a new backend that uses the library.
(Currently, only [Sparkey](https://github.com/spotify/sparkey) is supported.)
Backends only need to implement a small set of methods (`[]`, `[]=`, `close`,
`delete`, `each`, `uid`), but can override the default implementation of other
methods if the underlying library supports more efficient implementations.

## Installation

### Requirements

 * [Gnista](https://github.com/emnl/gnista), Ruby bindings for Sparkey
 * [Sparkey](https://github.com/spotify/sparkey), constant key/value storage library
 * [Snappy](https://code.google.com/p/snappy/), compression/decompression library (unused, but required to compile Sparkey)
 * A filesystem that supports `flock(2)` and unlinking files/directories with outstanding file descriptors (ext3/4 will do just fine)


### Installation

Add the following line to your Gemfile:

    gem 'hammerspace'

Then run:

    bundle

### Vagrant

To make development easier, the source tree contains a Vagrantfile and a small
cookbook to install all the prerequisites. The vagrant environment also serves
as a consistent environment to run the test suite.

To use it, make sure you have vagrant installed, then:

    vagrant up
    vagrant ssh
    bundle exec rspec


## Usage

### Getting Started

For the most part, hammerspace acts like a Ruby hash. But since it's a hash
that persists on disk, you have to tell it where to store the files. The
enclosing directory and any parent directories are created if they don't
already exist.

```ruby
h = Hammerspace.new("/tmp/hammerspace")

h["cartoons"] = "mallets"
h["games"]    = "inventory"
h["rubyists"] = "data"

h.size          #=> 3
h["cartoons"]   #=> "mallets"

h.map { |k,v| "#{k.capitalize} use hammerspace to store #{v}." }

h.close
```

You should call `close` on the hammerspace object when you're done with it.
This flushes any pending writes to disk and closes any open file handles.


### Options

The constructor takes a hash of options as an optional second argument.
Currently the only option supported is `:backend` which specifies which backend
class to use. Since there is only one backend supported at this time, there is
currently no reason to pass this argument.

```ruby
h = Hammerspace.new("/tmp/hammerspace", {:backend => Hammerspace::Backend::Sparkey})
```


### Default Values

The constructor takes a default value as an optional third argument. This
functions the same as Ruby's `Hash`, except with `Hash` it is the first
argument.

```ruby
h = Hammerspace.new("/tmp/hammerspace", {}, "default")
h["foo"] = "bar"
h["foo"]  #=> "bar"
h["new"]  #=> "default"
h.close
```

The constructor also takes a block to specify a default Proc, which works the
same way as Ruby's `Hash`. As with `Hash`, it is the block's responsibility to
store the value in the hash if required.

```ruby
h = Hammerspace.new("/tmp/hammerspace") { |hash, key| hash[key] = "#{key} (default)" }
h["new"]  #=> "new (default)"
h.has_key?("new")  #=> true
h.close
```


### Supported Data Types

Only string keys and values are supported.

```ruby
h = Hammerspace.new("/tmp/hammerspace")
h[1] = "foo"     #=> TypeError
h["fixnum"] = 8  #=> TypeError
h["nil"] = nil   #=> TypeError
h.close
```

Ruby hashes store references to objects, but hammerspace stores raw bytes. A
new Ruby `String` object is created from those bytes when a key is accessed.

```ruby
value = "bar"

hash = {"foo" => value}
hash["foo"] == value       #=> true
hash["foo"].equal?(value)  #=> true

hammerspace = Hammerspace.new("/tmp/hammerspace")
hammerspace["foo"] = value
hammerspace["foo"] == value       #=> true
hammerspace["foo"].equal?(value)  #=> false
hammerspace.close
```

Since every access results in a new `String` object, mutating values doesn't
work unless you create an explicit reference to the string.

```ruby
h = Hammerspace.new("/tmp/hammerspace")
h["foo"] = "bar"

# This doesn't work like Ruby's Hash because every access creates a new object
h["foo"].upcase!
h["foo"]  #=> "bar"

# An explicit reference is required
value = h["foo"]
value.upcase!
value  #=> "BAR"

# Another access, another a new object
h["foo"]  #=> "bar"

h.close
```

This also imples that strings "lose" their encoding when retrieved from
hammerspace.

```ruby
value = "bar"
value.encoding  #=> #<Encoding:UTF-8>

h = Hammerspace.new("/tmp/hammerspace")
h["foo"] = value
h["foo"].encoding  #=> #<Encoding:ASCII-8BIT>
h.close
```

If you require strings in UTF-8, make sure strings are encoded as UTF-8 when
storing the key, then force the encoding to be UTF-8 when accessing the key.

```ruby
h[key] = value.encode('utf-8')
value = h[key].force_encoding('utf-8')
```


### Persistence

Hammerspace objects are backed by files on disk, so even a new object may
already have data in it.

```ruby
h = Hammerspace.new("/tmp/hammerspace")
h["foo"] = "bar"
h.close

h = Hammerspace.new("/tmp/hammerspace")
h["foo"]  #=> "bar"
h.close
```

Calling `clear` deletes the data files on disk. The parent directory is not
removed, nor is it guaranteed to be empty. Some files containing metadata may
still be present, e.g., lock files.


### Concurrency

Multiple concurrent readers are supported. Readers are isolated from writers,
i.e., reads are consistent to the time that the reader was opened. Note that
the reader opens its files lazily on first read, not when the hammerspace
object is created.

```ruby
h = Hammerspace.new("/tmp/hammerspace")
h["foo"] = "bar"
h.close

reader1 = Hammerspace.new("/tmp/hammerspace")
reader1["foo"]  #=> "bar"

writer = Hammerspace.new("/tmp/hammerspace")
writer["foo"] = "updated"
writer.close

# Still "bar" because reader1 opened its files before the write
reader1["foo"]  #=> "bar"

# Updated key is visible because reader2 opened its files after the write
reader2 = Hammerspace.new("/tmp/hammerspace")
reader2["foo"]  #=> "updated"
reader2.close

reader1.close
```

A new hammerspace object does not necessarily need to be created. Calling
`close` will close the files, then the reader will open them lazily again on
the next read.

```ruby
h = Hammerspace.new("/tmp/hammerspace")
h["foo"] = "bar"
h.close

reader = Hammerspace.new("/tmp/hammerspace")
reader["foo"]  #=> "bar"

writer = Hammerspace.new("/tmp/hammerspace")
writer["foo"] = "updated"
writer.close

reader["foo"]  #=> "bar"

# Close files now, re-open lazily on next read
reader.close

reader["foo"]  #=> "updated"
reader.close
```

If no hammerspace files exist on disk yet, the reader will fail to open the
files. It will try again on next read.

```ruby
reader = Hammerspace.new("/tmp/hammerspace")
reader.has_key?("foo")  #=> false

writer = Hammerspace.new("/tmp/hammerspace")
writer["foo"] = "bar"
writer.close

# Files are opened here
reader.has_key?("foo")  #=> true
reader.close
```

You can call `uid` to get a unique id that identifies the version of the files
being read. `uid` will be `nil` if no hammerspace files exist on disk yet.

```ruby
reader = Hammerspace.new("/tmp/hammerspace")
reader.uid  #=> nil

writer = Hammerspace.new("/tmp/hammerspace")
writer["foo"] = "bar"
writer.close

reader.close
reader.uid  #=> "24913_53943df0-e784-4873-ade6-d1cccc848a70"

# The uid changes on every write, even if the content is the same, i.e., it's
# an identifier, not a checksum
writer["foo"] = "bar"
writer.close

reader.close
reader.uid  #=> "24913_9371024e-8c80-477b-8558-7c292bfcbfc1"

reader.close
```

Multiple concurrent writers are also supported. When a writer flushes its
changes it will overwrite any previous versions of the hammerspace.

In practice, this works because hammerspace is designed to hold data that is
bulk-loaded from some authoritative external source. Rather than block writers
to enforce consistency, it is simpler to allow writers to concurrently attempt
to load the data. The last writer to finish loading the data and flush its
writes will have its data persisted.

```ruby
writer1 = Hammerspace.new("/tmp/hammerspace")
writer1["color"] = "red"

# Can start while writer1 is still open
writer2 = Hammerspace.new("/tmp/hammerspace")
writer2["color"] = "blue"
writer2["fruit"] = "banana"
writer2.close

# Reads at this point see writer2's data
reader1 = Hammerspace.new("/tmp/hammerspace")
reader1["color"]  #=> "blue"
reader1["fruit"]  #=> "banana"
reader1.close

# Replaces writer2's data
writer1.close

# Reads at this point see writer1's data; note that "fruit" key is absent
reader2 = Hammerspace.new("/tmp/hammerspace")
reader2["color"]  #=> "red"
reader2["fruit"]  #=> nil
reader2.close
```


### Flushing Writes

Flushing a write incurs some overhead to build the on-disk hash structures that
allows fast lookup later. To avoid the overhead of rebuilding the hash after
every write, most write operations do not implicitly flush. Writes can be
flushed explicitly by calling `close`.

Delaying flushing of writes has the side effect of allowing "transactions" --
all unflushed writes are private to the hammerspace object doing the writing.

One exception is the `clear` method which deletes the files on disk. If a
reader attempts to open the files immediately after they are deleted, it will
perceive the hammerspace to be empty.

```ruby
h = Hammerspace.new("/tmp/hammerspace")
h["yesterday"] = "foo"
h["today"]     = "bar"
h.close

reader1 = Hammerspace.new("/tmp/hammerspace")
reader1.keys  #=> ["yesterday", "today"]
reader1.close

# Writer wants to remove everything except "today"
writer = Hammerspace.new("/tmp/hammerspace")
writer.clear

# Effect of clear is immediately visible to readers
reader2 = Hammerspace.new("/tmp/hammerspace")
reader2.keys  #=> []
reader2.close

writer["today"] = "bar"
writer.close

reader3 = Hammerspace.new("/tmp/hammerspace")
reader3.keys  #=> ["today"]
reader3.close
```

If you want to replace the existing data with new data without flushing in
between (i.e., in a "transaction"), use `replace` instead.

```ruby
h = Hammerspace.new("/tmp/hammerspace")
h["yesterday"] = "foo"
h["today"]     = "bar"
h.close

reader1 = Hammerspace.new("/tmp/hammerspace")
reader1.keys  #=> ["yesterday", "today"]
reader1.close

# Writer wants to remove everything except "today"
writer = Hammerspace.new("/tmp/hammerspace")
writer.replace({"today" => "bar"})

# Old keys still present because writer has not flushed yet
reader2 = Hammerspace.new("/tmp/hammerspace")
reader2.keys  #=> ["yesterday", "today"]
reader2.close

writer.close

reader3 = Hammerspace.new("/tmp/hammerspace")
reader3.keys  #=> ["today"]
reader3.close
```


### Interleaving Reads and Writes

To ensure writes are available to subsequent reads, every read operation
implicitly flushes any previous writes.

```ruby
h = Hammerspace.new("/tmp/hammerspace")
h["foo"] = "bar"

# Implicitly flushes write (builds on-disk hash for fast lookup), then opens
# newly written on-disk hash for reading
h["foo"]  #=> "bar"

h.close
```

While batch reads or writes are relatively fast, interleaved reads and writes
are slow because the hash is rebuilt very often.

```ruby
# One flush, fast
h = Hammerspace.new("/tmp/hammerspace")
h["a"] = "100"
h["b"] = "200"
h["c"] = "300"
h["a"]  #=> "100"
h["b"]  #=> "200"
h["c"]  #=> "300"
h.close

# Three flushes, slow
h = Hammerspace.new("/tmp/hammerspace")
h["a"] = "100"
h["a"]  #=> "100"
h["b"] = "200"
h["b"]  #=> "200"
h["c"] = "300"
h["c"]  #=> "300"
h.close
```

To avoid this overhead, and to ensure consistency during iteration, the `each`
method opens its own private reader for the duration of the iteration. This is
also true for any method that uses `each`, including all methods provided by
`Enumerable`.

```ruby
h = Hammerspace.new("/tmp/hammerspace")
h["a"] = "100"
h["b"] = "200"
h["c"] = "300"

# Flushes the above writes, then opens a private reader for the each call
h.each do |key, value|
  # Writes are done in bulk without flushing in between
  h[key] = value[0]
end

# Flushes the above writes, then opens the reader
h.to_hash  #=> {"a"=>"1", "b"=>"2", "c"=>"3"}

h.close
```


### Unsupported Methods

Besides the incompatibilities with Ruby's `Hash` discussed above, there are
some `Hash` methods that are not supported.

 * Methods that return a copy of the hash: `invert`, `merge`, `reject`, `select`
 * `rehash` is not needed, since hammerspace only supports string keys, and keys are effectively `dup`d
 * `delete` does not return the value deleted, and it does not support block usage
 * `hash` and `to_s` are not overriden, so the behavior is that of `Object#hash` and `Object#to_s`
 * `compare_by_identity`, `compare_by_identity?`
 * `pretty_print`, `pretty_print_cycle`
