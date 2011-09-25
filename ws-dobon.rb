# -*- coding: utf-8 -*-
require 'rubygems'
require 'sequel'
require 'sinatra'

### Configs

# cookie setting.
use Rack::Session::Cookie,
  :expire_after => 2592000,
  :secret => 'change_me'

### Models

# connect to database.
Sequel::Model.plugin(:schema)
Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://db/database.sqlite3')

### Routes
#
get '/' do
  '日本語'
end
