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

EXCLUDED_HEADERS = [
  'HTTP_X_FORWARDED_FOR',
  'HTTP_X_REAL_IP',
  'HTTP_X_REQUEST_START',
  'HTTP_X_VARNISH'
]

configure :development do
  uri = URI.parse('redis://localhost:6379')
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  disable :protection
end

configure :production do
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  disable :protection
end

configure do
  enable :sessions
end

helpers do
  def code
    params[:splat][0]
  end

  def config_key
    "code:#{code}:config"
  end

  def requests_key
    "code:#{code}:requests"
  end

  def view?
    request.query_string =~ /^view$/i
  end

  def destroy?
    request.query_string =~ /^destroy$/i
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
      data.each { |req| req["time"] = Time.at(req["time"].to_f).utc }
    end
  end

  def store_request
    REDIS.multi do
      REDIS.lpush requests_key, package_request # append the request to the end
      REDIS.ltrim requests_key, 0, 9 # restrict to 10 items (but trim the first part of the list, keeping the last 10)
      REDIS.expire requests_key, 172800 # delete all requests after 2 days: 2 * 24 * 60 * 60
    end
  end

  def package_request
    {
      :time => Time.now.utc.to_f,
      :ip => request.ip,
      :method => request.request_method.upcase,
      :path => request.path,
      :headers => package_headers,
      :content_type => request.content_type,
      :content_length => request.content_length,
      :params => request.params,
      :body => package_body
    }.to_json
  end

  def package_headers
    pretty = {}
    # Select out all HTTP_* headers
    allowed_headers = request.env.select { |k,v| k =~ /^HTTP_/ }
    # Remove heroku headers
    allowed_headers.delete_if { |k,v| k =~ /heroku/i || EXCLUDED_HEADERS.include?(k) }
    # Add back CONTENT_LENGTH and CONTENT_TYPE
    allowed_headers['CONTENT_LENGTH'] = request.content_length unless request.content_length.nil?
    allowed_headers['CONTENT_TYPE'] = request.content_type unless request.content_type.nil?
    allowed_headers.each do |k,v|
      header = k.dup
      header.gsub!(/^HTTP_/, '')
      header = header.downcase.titlecase.tr(' ', '-')
      pretty[header] = v
    end
    return pretty
  end

  def package_body
    request.body.read if ((request.request_method == 'POST' || request.request_method == 'PUT') && !request.form_data?)
  end
end

get '/' do
  slim :index
end

['/*.:format?', '/*'].each do |path|
  get path do
    return slim(:view) if view?
    return [404, "Um, guess again?"] if unknown?

    store_request
    request.session_options[:skip] = true

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
      if !params[:json].to_s.empty? or !params[:xml].to_s.empty?
        msg << " Check out the <a href='#{url("/#{code}.json")}'>JSON</a> or <a href='#{url("/#{code}.xml")}'>XML</a>"
      end
      config_hash = {:json => params[:json].to_s, :xml => params[:xml].to_s, :updated_at => Time.now.utc.to_i}
      REDIS.set config_key, config_hash.to_json
      flash[:notice] = msg
      redirect to("/#{code}?view")
      return
    elsif destroy?
      REDIS.multi do
        REDIS.del config_key
        REDIS.del requests_key
      end
      flash[:warning] = "The endpoint was destroyed."
      redirect to("/#{code}?view")
      return
    end

    return 404 if unknown?

    store_request
    request.session_options[:skip] = true

    if json?
      json
    elsif xml?
      xml
    else
      "Howdy"
    end
  end

  put path do
    return 404 if unknown?

    store_request
    request.session_options[:skip] = true

    if json?
      json
    elsif xml?
      xml
    else
      "Howdy"
    end
  end

end
