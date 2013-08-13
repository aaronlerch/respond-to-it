require 'securerandom'
require 'rest_client'

module Runscope
  RUNSCOPE_ID = ENV["RESPONDTOIT_RUNSCOPE_ID"]
  RUNSCOPE_SECRET = ENV["RESPONDTOIT_RUNSCOPE_SECRET"]

  module Helpers
    def supports_runscope?
      Runscope::RUNSCOPE_ID && Runscope::RUNSCOPE_SECRET
    end

    def runscope_id
      Runscope::RUNSCOPE_ID
    end

    def runscope_authenticated?
      !session[:runscope_access_token].nil?
    end

    def requires_runscope
      halt(404, "Runscope not supported") if !supports_runscope?
    end

    def requires_authenticated_runscope
      requires_runscope
      halt(404, "Not authenticated with Runscope") if !runscope_authenticated?
    end

    def runscope_buckets
      session[:runscope_buckets] ||= fill_runscope_buckets
    end

    def fill_runscope_buckets
      return nil if !session[:runscope_access_token]
      response = RestClient.get "https://api.runscope.com/buckets", authorization: "Bearer #{session[:runscope_access_token]}"
      if response.code == 200
        result = JSON.parse(response)
        session[:runscope_buckets] = result["data"].map { |e| { "default" => e["default"], "key" => e["key"], "name" => e["name"] } }
      end

      session[:runscope_buckets]
    end

    def default_runscope_bucket_key
      default_bucket = runscope_buckets.find { |b| b["default"] }
      default_bucket["key"] if default_bucket
    end

    def runscope_state
      session[:runscope_state] ||= SecureRandom.uuid
    end
  end
end

class RespondToIt < Sinatra::Base
  get '/runscope/oauth' do
    requires_runscope
    halt(400) if !params[:code]
    halt(400) if params[:state] != runscope_state
    
    response = RestClient.post("https://www.runscope.com/signin/oauth/access_token",
                    {
                      client_id: RUNSCOPE_ID,
                      client_secret: RUNSCOPE_SECRET,
                      code: params[:code],
                      grant_type: 'authorization_code',
                      redirect_uri: url('/runscope/oauth')
                    })

    if response.code == 200
      result = JSON.parse(response)
      session[:runscope_access_token] = result["access_token"]
    end

    redirect to(session[:last_view] || "/")
  end

  get '/runscope/logout' do
    session[:runscope_access_token] = session[:runscope_buckets] = nil
    redirect to(session[:last_view] || "/")
  end

  post '/runscope/export' do
    requires_authenticated_runscope
    
    halt(404, "Unknown request") if !code
    bucket_key = params[:bucket_key] || default_runscope_bucket_key
    halt(404, "Unable to determine destination bucket") if !bucket_key
    req = requests.find { |r| params[:id] && r['id'] == params[:id] }
    halt(404, "Unable to find the specified request") if req.nil?

    data = {
        request: {
          method: req['method'],
          url: url(req['path']),
          headers: req['headers'] || {},
          form: req['params'] || {},
          body: req['body'] || '',
          timestamp: req['time'].to_f
        }
      }.to_json

    resp = RestClient.post "https://api.runscope.com/buckets/#{bucket_key}/messages", 
                           data, 
                           { content_type: :json, authorization: "Bearer #{session[:runscope_access_token]}" }

    if resp.code == 200
      respData = JSON.parse(resp)
      if respData['meta']['error_count'].to_i > 0
        puts "Error exporting a request to runscope: #{resp}"
        halt(500, "Error exporting the request to Runscope")
      end
      
      # Success! Build the link
      "https://www.runscope.com/stream/#{bucket_key}"
    end
  end
end