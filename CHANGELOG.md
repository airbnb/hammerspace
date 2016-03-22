# v0.1.6
* Avoid calling mkdir_p unless needed because it uses exceptions for control flow.

# v0.1.5
* Avoid an unnecessary call to Gnista::Hash#include? on get.

# v0.1.4
* Upgrade to gnista 0.0.5.
* Remove work around for gnista bug.

# v0.1.3
* Work around gnista bug that causes ruby crashes on OS X.
* Upgrade to sparkey 0.2.0 in vagrant.

# v0.1.2
* Support vagrant for local development.
* Remove dependency on colored gem.
* Add MIT license.
* Documentation updates.

# v0.1.1
* Expose the uid of the directory that the current reader is reading from.
* Documentation updates.

# v0.1.0
* Change semantics of block passed to constructor, now used to specify default_proc.
* Add support for most Ruby Hash methods.
* Major internal refactor, new HashMethods module allows new backends to be written more easily.
* Add documentation.

# v0.0.2
* Add support for multiple writers with last-write-wins semantics.
* Implement `clear` method.

# v0.0.1
* Initial release.
