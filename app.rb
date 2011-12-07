require 'sinatra'
require 'slim'

get '/' do
  slim :index
end

get "/:code" do
  slim :editor
end
