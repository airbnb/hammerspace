default.hammerspace_development.sparkey.home = "/home/#{default.hammerspace_development.user}/sparkey"
default.hammerspace_development.sparkey.source_file = "https://github.com/spotify/sparkey/archive/#{node.hammerspace_development.sparkey.version}.tar.gz"
default.hammerspace_development.sparkey.local_dir = File.join(default.hammerspace_development.sparkey.home, "sparkey-#{node.hammerspace_development.sparkey.version}")

default.hammerspace_development.sparkey.packages = [
  'libsnappy-dev',
]
