require 'rubygems'
require 'rake'
require 'sequel'
require 'sequel/extensions/migration'

namespace :db do
  desc 'migrate database'
  task :migrate do

    DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://db/database.sqlite3')
    Sequel::Migrator.apply(DB, './migrate')
  end
end
