require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

configure do 
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

before do
  @root = File.expand_path("..", __FILE__)

  @files = Dir.glob(@root + "/data/*").map do |path|
    File.basename(path)
  end
end


get '/' do

  erb :index
end

get '/:filename' do
  file_path = @root + "/data/" + params[:filename]

  if @files.include?("#{params[:filename]}")
    headers["Content-Type"] = "text/plain"
    File.read(file_path)
  else
    session[:error] = "#{params[:filename]} does not exist."
    redirect '/'
  end
end