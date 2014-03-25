# v0.2.0
* Switch to adamtanner's sparkey bindings, fixes ruby crashes on OS X.
* Upgrade to latest sparkey (0.2.0) in vagrant; required for sparkey bindings.

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
