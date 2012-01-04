require 'sinatra'
require 'slim'
require 'redis'
require 'json'
require 'sinatra/flash'

class String
  def titlecase
    tr('_', ' ').
    gsub(/\s+/, ' ').
    gsub(/\b\w/){ $`[-1,1] == "'" ? $& : $&.upcase }
  end
end

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
  def config_key
    "code:#{params[:code]}:config"
  end

  def requests_key
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

  def known?
    config[:known]
  end

  def unknown?
    !known?
  end

  def active_if_unknown
    'active' if unknown?
  end

  def active_if_known
    'active' if known?
  end

  def config
    @config ||= begin
      data = REDIS.get config_key
      if data.nil?
        data = { :known => false }
      else
        data = JSON.parse(data)
        data[:known] = true
      end
      data
    end
  end

  def requests
    @requests ||= begin
      data = REDIS.lrange requests_key, 0, 9
      data.map! { |req| JSON.parse(req) }
      data.each { |req| req["time"] = Time.at(req["time"].to_i) }
    end
  end

  def store_request
    REDIS.multi do
      REDIS.lpush requests_key, package_request # append the request to the end
      REDIS.ltrim requests_key, 0, 9 # restrict to 10 items (but trim the first part of the list, keeping the last 10)
    end
  end

  def package_request
    {
      :time => Time.now.utc.to_i,
      :ip => request.ip,
      :method => request.request_method.upcase,
      :path => request.fullpath,
      :headers => package_headers
      # todo: store the body and form post data as well
    }.to_json
  end

  def package_headers
    pretty = {}
    allowed_headers = request.env.select { |k,v| k =~ /^HTTP_/ }
    allowed_headers.each do |k,v|
      header = k.dup
      header.gsub!(/^HTTP_/, '')
      header = header.downcase.titlecase.tr(' ', '-')
      pretty[header] = v
    end
    return pretty
  end
end

get '/' do
  slim :index
end

get '/test.:code' do
  requests.inspect.class
end

['/:code.:format?', '/:code'].each do |path|
  get path do
    return slim(:view) if view?
    return [404, "Um, guess again?"] if unknown?

    store_request

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
      msg = "The response was #{known? ? 'updated' : 'created'} successfully."
      config_hash = {:json => params[:json].to_s, :xml => params[:xml].to_s, :updated_at => Time.now.utc.to_i}
      REDIS.set config_key, config_hash.to_json
      flash[:notice] = msg
      redirect to("/#{params[:code]}?view")
      return
    end

    return 404 if unknown?

    store_request

    if json?
      json
    elsif xml?
      xml
    else
      "Howdy"
    end
  end
end
