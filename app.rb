require 'sinatra'
require 'slim'
require 'redis'
require 'json'
require 'sass'
require 'rack-flash'

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
  use Rack::Flash, :sweep => true
end

helpers do
  def config_key(code)
    "code:#{params[:code]}:config"
  end

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
      data = REDIS.get config_key(params[:code])
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
    "<label for=\"#{method_name}\"><input type=\"checkbox\" name=\"#{method_name}\" value=\"#{method_name}\" #{checked} /><span>#{method_name.upcase}</label>"
  end
end

get '/' do
  slim :index
end

get '/app.css' do
  scss :style
end

['/:code.:format?', '/:code'].each do |path|
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
    if browser?
      config_hash = {"get" => !!params["get"], "post" => !!params["post"], "json" => params["json"].to_s, "xml" => params["xml"].to_s}
      REDIS.set config_key(params[:code]), config_hash.to_json
      flash[:notice] = "The response was updated successfully."
      redirect to("/#{params[:code]}")
      return
    end

    return 404 if not !!config["post"]

    if json?
      json
    elsif xml?
      xml
    end
  end
end
