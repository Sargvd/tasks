# encoding: utf-8

require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require 'sinatra/reloader'
require 'sass'
require 'haml'
require 'coffee-script'
require 'pg'
require 'singleton'
require 'yaml'

#Sinatra configuration
set :root, File.dirname(__FILE__)
set :public_folder => File.join(settings.root, 'static')
set :views, File.join(settings.root, 'templates')
set :sass, :views => File.join(settings.public_folder, 'sass')
set :coffee, :views => File.join(settings.public_folder, 'js')
set :environment => :development
set :show_exceptions, false
set :raise_errors, false

#24 hours session timeout
use Rack::Session::Cookie, :expire_after => 60*60*24

set(:authorized) {|auth_required| condition {redirect '/auth/login', 303 unless auth_required && logged_in?}}
set(:ajax) {|auth_required| condition {halt [403, 'Not authorized.'] if auth_required && (not logged_in?)}}

#Dispatcher
require './lib/dispatcher/auth.rb' # /auth/*
require './lib/dispatcher/static.rb' # /(js|css)/*
require './lib/dispatcher/tasks.rb' # /tasks/*
require './lib/dispatcher/user.rb' # /user/*
require './lib/dispatcher/actions.rb' # /actions/*

class NoConfig < Exception
end

class DBError < Exception
end

class MyConn
  include Singleton
  attr_accessor :conn
  def exec(*args)
    @conn.exec *args
  end
  def initialize
    begin
      config = YAML.load_file(File.join(settings.root, 'config.yaml'))
      mconfig = {}
      config.to_hash.each_pair {|k,v| mconfig[k.to_sym] = v}
      p mconfig
      @conn = PGconn.open mconfig
    rescue Errno::ENOENT
      raise NoConfig
    rescue PG::Error => message
      raise DBError, message
    end
  end
end

helpers do
  def logged_in?
    session[:auth] == 'Okay'
  end
  def sql_do(*args)
    MyConn.instance.exec *args
  end
end

get '/', :authorized => true do
  projects = sql_do('SELECT project_id, name FROM projects WHERE user_id=$1 ORDER BY project_id', [session[:user_id]]).values
  session[:project_tab] = projects[0][0] unless (session.has_key? [:project_tab] or projects.size == 0)
  session[:mode] = 'tasks_view'
  haml :main
end

get '/bar', :ajax => true do
  projects = sql_do('SELECT project_id, name FROM projects WHERE user_id=$1 ORDER BY project_id', [session[:user_id]]).values
  haml :navbar,
       :locals => {
           :uri => (request.referer + ' ').split('/')[-1].chomp(' '), # + ' ' is to handle '/' uri
           :mode => session[:mode],
           :mail => session[:mail],
           :admin => session[:admin],
           :projects => projects,
           :active_tab => session[:project_tab]
       }
end

post '/projects/add/:name' do
  sql_do('INSERT INTO projects (name, user_id) VALUES ($1, $2)',
      [params[:name], session[:user_id]])
end

post '/projects/del/:project_id' do
  MyConn.instance.conn.transaction do |conn|
    task_ids = conn.exec('SELECT task_id FROM tasks WHERE project_id=$1 AND user_id=$2',
                         [params[:project_id], session[:user_id]]).values.flatten
    p task_ids
    conn.exec('DELETE FROM actions WHERE user_id=$1 AND task_id = ANY($2::int[])', [session[:user_id], "{#{task_ids.join ','}}"]) unless task_ids.empty?
    conn.exec('DELETE FROM tasks WHERE user_id=$1 AND task_id = ANY($2::int[])', [session[:user_id], "{#{task_ids.join ','}}"]) unless task_ids.empty?
    conn.exec('DELETE FROM projects WHERE user_id=$1 AND project_id=$2', [session[:user_id], params[:project_id]])
  end
end

get '/projects/reset_id' do
  projects = sql_do('SELECT project_id, name FROM projects WHERE user_id=$1 ORDER BY project_id', [session[:user_id]]).values
  session[:project_tab] = projects[0][0] unless session.has_key? [:project_tab] || projects.size == 0
end

get '/projects/is_empty/:id' do
  projects = sql_do('SELECT count(*) FROM tasks WHERE user_id=$1 AND project_id=$2', [session[:user_id], params[:id]]).values[0][0]
  p projects
  halt 500 unless projects.to_i == 0
  halt 200
end

post '/bar/tab/:clicked_tab_id', :ajax => true do
  session[:project_tab] = params[:clicked_tab_id]
  session[:tag_active] = 'Active'
end

get '/error/no_config' do
  haml :error_no_config
end

error NoConfig do
  redirect to '/error/no_config'
end

get '/error/not_authorized' do
  haml :error_not_authorized
end

error DBError do
  @error_text = env['sinatra.error']
  haml :error
end
