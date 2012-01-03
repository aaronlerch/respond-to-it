require 'sinatra'
require 'slim'
require 'redis'
require 'json'
require 'sinatra/flash'

configure :development do
  uri = URI.parse('redis://localhost:6379')
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end

configure :production do
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end

configure do
  enable :sessions
end

helpers do
  def config_key(code)
    "code:#{params[:code]}:config"
  end

  def requests_key(code)
    "code:#{params[:code]}:requests"
  end

  def view?
    request.query_string =~ /^view$/i
  end

  def json?
    request.accept.first == "application/json" || params[:format] =~ /json/i
  end

  def json
    content_type :json
    config["json"]
  end

  def xml?
    request.accept.first == "application/xml" || params[:format] =~ /xml/i
  end

  def xml
    content_type :xml
    config["xml"]
  end

  def config
    @config ||= begin
      data = REDIS.get config_key(params[:code])
      result = JSON.parse(data) unless data.nil?
    end
  end
end

get '/' do
  slim :index
end

['/:code.:format?', '/:code'].each do |path|
  get path do
    return slim(:view) if view?
    return [404, "Um, guess again?"] if config.nil?

    if json?
      json
    elsif xml?
      xml
    else
      "Howdy"
    end
  end

  post path do
    if view?
      config_hash = {"json" => params["json"].to_s, "xml" => params["xml"].to_s}
      REDIS.set config_key(params[:code]), config_hash.to_json
      flash[:notice] = "The response was updated successfully."
      return slim(:view)
    end

    return 404 if config.nil?

    if json?
      json
    elsif xml?
      xml
    else
      "Howdy"
    end
  end
end
