# coding: utf-8

# mode development/production
mode = "development"

Sequel::Model.plugin(:schema)

db = {
  user:     ENV['USER'],
  dbname:   ENV['DBNAME'],
  password: ENV['PASSWORD'],
  host:     ENV['HOST']
}

if mode == 'development'
  DB = Sequel.connect("sqlite://users.db")
  session_domain = '127.0.0.1'
elsif mode == 'production'
  DB = Sequel.connect("mysql2://#{db[:user]}:#{db[:password]}@#{db[:host]}/#{db[:dbname]}")
  session_domain = 'www.notekun.com'
end

class Users < Sequel::Model
  unless table_exists?
    DB.create_table :users do
      primary_key :id
      String :nickname
    end
  end
end

use Rack::Session::Cookie,
  :key => 'rack.session',
  :domain => session_domain,
  :path => '/',
  :expire_after => 3600,
  :secret => ENV['SESSION_SECRET']

use OmniAuth::Builder do
  provider :twitter, ENV['TWITTER_CONSUMER_KEY'], ENV['TWITTER_CONSUMER_SECRET']
end

Twitter.configure do |config|
  config.consumer_key       = ENV['TWITTER_CONSUMER_KEY']
  config.consumer_secret    = ENV['TWITTER_CONSUMER_SECRET']
  config.oauth_token        = ENV['TWITTER_SHIKAKUN_TOKEN']
  config.oauth_token_secret = ENV['TWITTER_SHIKAKUN_TOKEN_SECRET']
end

get "/" do
  if session["nickname"].nil?
    haml :index
  else
    haml :dashboard
  end
end

get "/auth/:provider/callback" do
  auth = request.env["omniauth.auth"]
  session["nickname"] = auth["info"]["nickname"]
  redirect '/join'
end

get '/join' do
  if session["nickname"].nil?
    redirect '/'
  else
    if Users.filter(nickname: session["nickname"]).empty?
      Users.find_or_create(:nickname => session["nickname"])
      redirect '/'
    else
      redirect '/'
    end
  end
end

get "/cancel" do
  if session["nickname"].nil?
    redirect '/'
  else
    Users.filter(:nickname => session["nickname"]).delete
    redirect '/logout'
  end
end

get "/logout" do
  session.clear
  redirect '/'
end