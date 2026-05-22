# config valid for current version and patch releases of Capistrano
lock "~> 3.20.1"

set :application, "decidim_forosocial"
set :repo_url, "git@github.com:forosocial/decidim.git"

set :deploy_to, "/home/decidim/capistrano_decidim"
set :branch, "main"

# Linked files
set :linked_files, %w{
  config/master.key
  .rbenv-vars
}

# Linked directories
set :linked_dirs, %w{
  log
  tmp/pids
  tmp/cache
  tmp/sockets
  storage
}

# Entorno para Node/Ruby
set :default_env, {
  'PATH' => "/home/decidim/.nvm/versions/node/v18.20.8/bin:/home/decidim/.rbenv/shims:/home/decidim/.rbenv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin",
  'NVM_DIR' => "/home/decidim/.nvm",
  'NODE_ENV' => "production",
  'RAILS_ENV' => "production"
}

# Fuerza explícitamente node/npm correctos
SSHKit.config.command_map[:node] = "/home/decidim/.nvm/versions/node/v18.20.8/bin/node"
SSHKit.config.command_map[:npm]  = "/home/decidim/.nvm/versions/node/v18.20.8/bin/npm"

# rbenv
set :rbenv_type, :user
set :rbenv_ruby, File.read(".ruby-version").strip

# Mantener releases
set :keep_releases, 5

# Logs
set :log_level, :info