require "bundler/capistrano"
load 'deploy/assets'

set :application, "mountainofpromos.com"
set :repository,  "git@bigmux.qutek.net:promoweb"

set :deploy_to, "/var/www/#{application}"

ssh_options[:forward_agent] = true

set :scm, :git
set :deploy_via, :remote_cache # Don't duplicate repository
set :git_enable_submodules, 1 # Fetch submodules

# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

role :web, "main.mountainofpromos.com"                          # Your HTTP server, Apache/etc
role :app, "main.mountainofpromos.com"                          # This may be the same as your `Web` server
role :db,  "main.mountainofpromos.com", :primary => true # This is where Rails migrations will run
#role :db,  "your slave db-server here"

# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts

# If you are using Passenger mod_rails uncomment this:
namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join(current_path,'tmp','restart.txt')}"
  end

  namespace :phone do
    task :symlink, :roles => :web, :except => { :no_release => true } do
      run <<-CMD
        rm -rf #{latest_release}/public/phone &&
        ln -s #{shared_path}/phone #{latest_release}/public/phone &&
        ln -s #{shared_path}/secrets #{latest_release}/config/secrets
      CMD
    end
  end
end

before 'deploy:finalize_update', 'deploy:phone:symlink'
