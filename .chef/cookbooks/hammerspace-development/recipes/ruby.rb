package "ruby#{node.hammerspace_development.ruby.version}" do
  action :upgrade
  options "--force-yes"
end

package "ruby#{node.hammerspace_development.ruby.version}-dev" do
  action :upgrade
  options "--force-yes"
end

# other common packages needed by ruby gems
["libxslt-dev", "libxml2-dev"].each do |p|
  package p do
    action :upgrade
  end
end

gem_package 'bundler' do
  action :install
end

