# ------------
# APP SPECIFIC SETTINGS
# ------------
set :application, "home-chefs.com"
set :repository, "git@github.com:psq/opensourcerails.git"
set :server_name, "home-chefs.com"

set :scm, "git"
set :checkout, "export" 
set :deploy_via, :remote_cache

set :base_path, "/home/psq"
set :deploy_to, "/home/psq/#{application}"
set :apache_site_folder, "/etc/apache2/sites-enabled"

set :keep_releases, 3

set :user, 'psq'
set :runner, 'psq'

# =============================================================================
# You shouldn't have to modify the rest of these
# =============================================================================

role :web, server_name
role :app, server_name
role :db,  server_name, :primary => true

set :use_sudo, false

ssh_options[:paranoid] = false

# =============================================================================
# OVERRIDE TASKS
# =============================================================================
namespace :deploy do

  desc "Restart Passenger" 
  task :restart, :roles => :app do
    run "touch #{current_path}/tmp/restart.txt" 
    run "curl http://#{server_name}"
  end

  desc <<-DESC
    Deploy and run pending migrations. This will work similarly to the \
    `deploy' task, but will also run any pending migrations (via the \
    `deploy:migrate' task) prior to updating the symlink. Note that the \
    update in this case it is not atomic, and transactions are not used, \
    because migrations are not guaranteed to be reversible.
  DESC
  task :migrations do
    set :migrate_target, :latest
    update_code
    migrate
    symlink
    restart
  end
  
  # desc "restart apache"
  # task :restart_apache do
  #   sudo "/etc/init.d/apache2 stop"
  #   sudo "/etc/init.d/apache2 start"
  # end
  # 
  # desc "start apache cluster"
  # task :start_apache do
  #   sudo "/etc/init.d/apache2 start"
  # end
  # 
  # desc "stop apache cluster"
  # task :stop_apache do
  #   sudo "/etc/init.d/apache2 stop"
  # end
end

before "deploy:restart", "admin:migrate"

after  "deploy", "live:send_request"

# after "deploy:setup", "init:set_permissions"
after "deploy:setup", "init:create_shared"
# after "deploy:setup", "init:upload_config"
# after "deploy:setup", "init:database_yml"
# after "deploy:setup", "init:create_database"
# after "deploy:setup", "init:create_vhost"
# after "deploy:setup", "init:enable_site"
namespace :init do
  
  desc "setting proper permissions for deploy user"
  task :set_permissions do
    # sudo "chown -R deploy /var/www/production"
  end

  desc "create mysql db"
  task :create_database do
    #create the database on setup
    set :db_user, Capistrano::CLI.ui.ask("database user: ") unless defined?(:db_user)
    set :db_pass, Capistrano::CLI.password_prompt("database password: ") unless defined?(:db_pass)
    run "echo \"CREATE DATABASE #{application}_production\" | mysql -u #{db_user} --password=#{db_pass}"
  end
  
  desc "enable site"
  task :enable_site do 
    # sudo "ln -nsf #{shared_path}/config/apache_site.conf #{apache_site_folder}/#{application}"
  end

  desc "create shared"
  task :create_shared do
    run "mkdir -p #{shared_path}/config"
    run "echo place logo, tracking, database.yml and app_config.yml to #{shared_path}/config"
  end

  desc "upload config files"
  task :upload_config do
    upload("../#{application}/database.yml", "#{shared_path}/config/", :via => :scp)
    upload("../#{application}/app_config.yml", "#{shared_path}/config/", :via => :scp)
    upload("../#{application}/logo-hc.png", "#{shared_path}/config/", :via => :scp)
    upload("../#{application}/_tracking.html.erb", "#{shared_path}/config/", :via => :scp)
  end

  desc "create database.yml"
  task :database_yml do
    set :db_user, Capistrano::CLI.ui.ask("database user: ")
    set :db_pass, Capistrano::CLI.password_prompt("database password: ")
    database_configuration = %(
---
login: &login
  adapter: mysql
  database: #{application}_production
  host: localhost
  username: #{db_user}
  password: #{db_pass}

production:
  <<: *login
)
    put database_configuration, "#{shared_path}/config/database.yml"
  end
  
  desc "create vhost file"
  task :create_vhost do
    
    vhost_configuration = %(
<VirtualHost *>
  ServerName #{server_name}
  DocumentRoot /var/www/production/#{application}/current/public
</VirtualHost>
)
    
    put vhost_configuration, "#{shared_path}/config/apache_site.conf"
    
  end
  
end

after "deploy:update_code", "localize:install_gems"
after "deploy:update_code", "localize:copy_shared_configurations"
after "deploy:update_code", "localize:upload_folders"

namespace :deploy do
  desc "start"
  task :start do
    #no call to script/spin
  end
end

namespace :localize do
  desc "copy shared configurations to current"
  task :copy_shared_configurations, :roles => [:app] do
    %w[database.yml app_config.yml].each do |f|
      run "ln -nsf #{shared_path}/config/#{f} #{release_path}/config/#{f}"
    end
    %w[logo-hc.png].each do |f|
      run "ln -nsf #{shared_path}/config/#{f} #{release_path}/public/images/template/#{f}"
    end
    %w[_tracking.html.erb].each do |f|
      run "ln -nsf #{shared_path}/config/#{f} #{release_path}/app/views/layouts/#{f}"
    end
    %w[rails gems].each do |f|
      run "ln -nsf #{shared_path}/vendor/#{f} #{release_path}/vendor/#{f}"
    end
    %w[haml-2.0.2
        jcnetdev-active_record_without_table-1.1
        jcnetdev-acts_as_list-1.0.20080704
        jcnetdev-acts_as_state_machine-2.1.20080704
        jcnetdev-app_config-1.2
        jcnetdev-better_partials-1.0.200807042
        jcnetdev-paperclip-1.1
        jcnetdev-seed-fu-1.0.200807042
        jcnetdev-validates_as_email_address-1.11
        jcnetdev-will_paginate-2.3.21
        neorails-form_fu-0.51
        neorails-view_fu-0.4.20080711
        right_aws-1.7.3
        right_http_connection-1.2.3].each do |f|
      run "ln -nsf #{shared_path}/vendor/plugins/#{f} #{release_path}/vendor/plugins/#{f}"
    end
  end
  
  desc "installs / upgrades gem dependencies "
  task :install_gems, :roles => [:app] do
    # sudo "date" # fuck you capistrano
    # run "cd #{release_path} && sudo rake RAILS_ENV=production gems:install"
  end
  
  task :upload_folders, :roles => [:app] do
    # create symlink for screenshots
    run "mkdir -p #{deploy_to}/shared/screenshots"
    run "ln -s #{deploy_to}/shared/screenshots #{release_path}/public/screenshots"
    
    # create symlink for downloads
    run "mkdir -p #{deploy_to}/shared/downloads"
    run "ln -s #{deploy_to}/shared/downloads #{release_path}/public/downloads"
  end
  
end

namespace :live do
  desc "send request" 
  task :send_request do
    url = "http://#{server_name}"
    puts `curl #{url} -g`
  end
    
  desc "remotely console" 
  task :console, :roles => :app do
    input = ''
    run "cd #{current_path} && ./script/console production" do |channel, stream, data|
      next if data.chomp == input.chomp || data.chomp == ''
      print data
      channel.send_data(input = $stdin.gets) if data =~ /^(>|\?)>/
    end
  end
  
  desc "tail production log files" 
  task :tail_logs, :roles => :app do
    run "tail -f #{shared_path}/log/production.log -n 200" do |channel, stream, data|
      puts  # for an extra line break before the host name
      puts "#{channel[:host]}: #{data}" 
      break if stream == :err    
    end
  end

  desc "show environment variables" 
  task :env, :roles => :app do
    run "env"
  end
  
  task :show_env do
    run "env"
  end
  
  task :show_path do
    run "echo #{current_path}"
  end
  
  desc "remotely console" 
  task :console, :roles => :app do
    input = ''
    run "cd #{current_path} && ./script/console production" do |channel, stream, data|
      next if data.chomp == input.chomp || data.chomp == ''
      print data
      channel.send_data(input = $stdin.gets) if data =~ /^(>|\?)>/
    end
  end
  
  desc "tail production log files" 
  task :tail_logs, :roles => :app do
    run "tail -f #{shared_path}/log/production.log -n 200" do |channel, stream, data|
      puts  # for an extra line break before the host name
      puts "#{channel[:host]}: #{data}" 
      break if stream == :err    
    end
  end
end

namespace :admin do    
  task :set_schema_info do    
    new_schema_version = Capistrano::CLI.ui.ask "New Schema Info Version: "
    run "cd #{current_path} && ./script/runner --environment=production 'ActiveRecord::Base.connection.execute(\"UPDATE schema_info SET version=#{new_schema_version}\")'"
  end
  
  task :migrate do
    run "cd #{current_path} && rake RAILS_ENV=production db:migrate"
  end
  
  task :remote_rake do
    rake_command = Capistrano::CLI.ui.ask "Rake Command to run: "
    run "cd #{current_path} && rake RAILS_ENV=production #{rake_command}"
  end
end
