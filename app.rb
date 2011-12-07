require 'sinatra'
require 'slim'
require 'redis'
require 'json'

configure do
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end

helpers do
  def browser?
    # Poor man's sniffer: if the user agent accepts html first, give them the edit form.
    request.preferred_type =~ /text\/html/i && (params[:format].nil? || params[:format].empty?)
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
      puts "getting the config from REDIS"
      data = REDIS.get "#{params[:code]}:config"
      if data.nil?
        {}
      else
        JSON.parse(data)
      end
    end
  end

  def checkbox_for(method)
    method_name = method.to_s
    checked = "checked" if !!config[method_name]
    "<input type=\"checkbox\" name=\"#{method_name}\" value=\"#{method_name}\" #{checked} /> #{method_name.upcase}"
  end
end

get '/' do
  slim :index
end

['/with/:code.:format?', '/with/:code'].each do |path|
  get path do
    return slim(:editor) if browser?
    return 404 if not !!config["get"]

    if json?
      json
    elsif xml?
      xml
    end
  end

  post path do
    return 404 if not !!config["post"]

    if json?
      json
    elsif xml?
      xml
    end
  end
end

post '/with/:code/update' do
  config_hash = {"get" => !!params["get"], "post" => !!params["post"], "json" => params["json"].to_s, "xml" => params["xml"].to_s}
  REDIS.set "#{params[:code]}:config", config_hash.to_json
  redirect to("/with/#{params[:code]}")
end
