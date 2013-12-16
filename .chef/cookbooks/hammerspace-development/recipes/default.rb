include_recipe "hammerspace-development::essential"
include_recipe "hammerspace-development::sparkey"
include_recipe "hammerspace-development::ruby"

template "/home/#{node.hammerspace_development.user}/.bash_profile" do
  owner     node.hammerspace_development.user
  group     node.hammerspace_development.user
  mode      '0755'
end

directory node.hammerspace_development.hammerspace.gem_home do
  owner     node.hammerspace_development.user
  group     node.hammerspace_development.user
  mode      '0755'
  recursive true
  action    :create
end

execute "hammerspace-bundle-install" do
  cwd         node.hammerspace_development.hammerspace.home
  user        node.hammerspace_development.user
  group       node.hammerspace_development.user
  command     "bundle install --path #{node.hammerspace_development.hammerspace.gem_home}"
end

directory node.hammerspace_development.hammerspace.root do
  owner     node.hammerspace_development.user
  group     node.hammerspace_development.user
  mode      '0755'
  recursive true
  action    :create
end
