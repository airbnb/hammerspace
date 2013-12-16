sparkey_local_file = File.join(
  node.hammerspace_development.sparkey.home,
  File.basename(node.hammerspace_development.sparkey.source_file))

node.hammerspace_development.sparkey.packages.each do |p|
  package p do
    action :upgrade
  end
end

directory node.hammerspace_development.sparkey.home do
  owner     node.hammerspace_development.user
  group     node.hammerspace_development.user
  mode      '0755'
  recursive true
  action    :create
end

remote_file sparkey_local_file do
  source    node.hammerspace_development.sparkey.source_file
  owner     node.hammerspace_development.user
  group     node.hammerspace_development.user
  mode      "644"

  action    :create_if_missing
  notifies  :run, "execute[extract-sparkey-#{node.hammerspace_development.sparkey.version}]", :immediately
end

execute "extract-sparkey-#{node.hammerspace_development.sparkey.version}" do
  cwd       node.hammerspace_development.sparkey.home
  user      node.hammerspace_development.user
  command   "tar -xvzf #{sparkey_local_file}"

  action    :nothing
  notifies  :run, "bash[build-sparkey-#{node.hammerspace_development.sparkey.version}]", :immediately
end

bash "build-sparkey-#{node.hammerspace_development.sparkey.version}" do
  cwd       node.hammerspace_development.sparkey.local_dir
  user      node.hammerspace_development.user
  code <<-EOS
    autoreconf --install
    ./configure
    make
  EOS

  action    :nothing
  notifies  :run, "execute[install-sparkey-#{node.hammerspace_development.sparkey.version}]", :immediately
end

execute "install-sparkey-#{node.hammerspace_development.sparkey.version}" do
  cwd       node.hammerspace_development.sparkey.local_dir
  command   "make install && sudo ldconfig"

  action    :nothing
end
