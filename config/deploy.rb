set :application, "mountainofpromos.com"
set :repo_url,  "git@git.qutek.net:promoweb"

set :deploy_to, "/var/www/mountainofpromos.com"
set :scm, :git

# set :format, :pretty
# set :log_level, :debug
# set :pty, true

set :linked_files, %w{config/secrets}
set :linked_dirs, %w{log tmp/pids tmp/cache tmp/sockets public/phone}

set :ssh_options, { :forward_agent => true }

# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }
set :branch, "master"
set :deploy_via, :remote_cache # Don't duplicate repository
set :git_enable_submodules, 1 # Fetch submodules

namespace :deploy do

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

  after :finishing, 'deploy:cleanup'

end
