require 'sinatra'
require 'slim'
require 'redis'

configure do
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end

get '/' do
  slim :index
end

get "/:code" do
  slim :editor
end
