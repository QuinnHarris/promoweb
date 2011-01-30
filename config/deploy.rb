set :application, "mountainofpromos.com"
set :repository,  "http://svn.qutek.net/svn-code/promoweb/trunk"

# If you aren't deploying to /u/apps/#{application} on the target
# servers (which is the default), you can specify the actual location
# via the :deploy_to variable:
set :deploy_to, "/var/www/#{application}"

# If you aren't using Subversion to manage your source code, specify
# your SCM below:
# set :scm, :subversion

role :app, "main.mountainofpromos.com"
role :web, "main.mountainofpromos.com"
role :db,  "main.mountainofpromos.com", :primary => true

# Mongrel Recipes
require 'mongrel_cluster/recipes'
set :mongrel_conf, "#{current_path}/config/mongrel_cluster.yml"
