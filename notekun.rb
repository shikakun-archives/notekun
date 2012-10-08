# coding: utf-8

# mode development/production
mode = 'development'

Sequel::Model.plugin(:schema)

db = {
  user:     ENV['USER'],
  dbname:   ENV['DBNAME'],
  password: ENV['PASSWORD'],
  host:     ENV['HOST']
}

if mode == 'development'
  DB = Sequel.connect("sqlite://db.db")
  session_domain = '127.0.0.1'
elsif mode == 'production'
  DB = Sequel.connect("mysql2://#{db[:user]}:#{db[:password]}@#{db[:host]}/#{db[:dbname]}")
  session_domain = 'www.notekun.com'
end

class Users < Sequel::Model
  unless table_exists?
    DB.create_table :users do
      primary_key :id
      String :uid
      String :nickname
      String :image
      String :token
      String :secret
    end
  end
end

class Notes < Sequel::Model
  unless table_exists?
    DB.create_table :notes do
      primary_key :id
      String :title
      Text :body
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

get '/' do
  @notes = Notes.order_by(:id.desc)
  if session['nickname'].nil?
    haml :index
  else
    haml :dashboard
  end
end

get '/auth/:provider/callback' do
  auth = request.env["omniauth.auth"]
  session['uid'] = auth['uid']
  session['nickname'] = auth['info']['nickname']
  session['image'] = auth['info']['image']
  session['token'] = auth['credentials']['token']
  session['secret'] = auth['credentials']['secret']
  redirect '/join'
end

get '/join' do
  if session['uid'].nil?
    redirect '/'
  else
    if Users.filter(uid: session['uid']).empty?
      Users.find_or_create(
        :uid => session['uid'],
        :nickname => session['nickname'],
        :image => session['image'],
        :token => session['token'],
        :secret => session['secret']
      )
      redirect '/'
    else
      redirect '/'
    end
  end
end

get '/cancel' do
  if session['uid'].nil?
    redirect '/'
  else
    Users.filter(:uid => session['uid']).delete
    redirect '/logout'
  end
end

get '/logout' do
  session.clear
  redirect '/'
end

post '/-/post' do
  if session['uid'].nil?
    redirect '/'
  else
    Notes.find_or_create(
      :title => request[:title],
      :body => request[:body]
    )
    redirect '/'
  end
end