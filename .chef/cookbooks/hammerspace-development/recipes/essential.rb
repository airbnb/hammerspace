execute "first-apt-get-update" do
  command "apt-get update"
end

node.hammerspace_development.essential.packages.each do |p|
  package p do
    action :upgrade
  end
end
