require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

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

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

def data_path
  if ENV["RACK_ENV"] ==  "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

get '/' do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end

  erb :index
end

get '/new' do
  erb :new
end

post '/create' do
  filename = params[:filename].to_s

  if filename.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new
  else
    file_path = File.join(data_path, filename)

    File.write(file_path, "")
    session[:message] = "#{params[:filename]} has been created."

    redirect "/"
  end
end

get '/:filename' do
  file_path = File.join(data_path, params[:filename])

  if File.file?(file_path)
    load_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect '/'
  end
end

get '/:filename/edit' do
  @filename = params[:filename]
  file_path = File.join(data_path, @filename)
  @content = File.read(file_path)

  erb :edit
end

post '/:filename/edit' do
  file_path = @root + "/data/" + params[:filename]

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been successfully updated."
  redirect "/"
end

post '/:filename/delete' do
  @filename = params[:filename]
  file_path = File.join(data_path, @filename)

  File.delete(file_path)

  session[:message] = "#{params[:filename]} has been successfully deleted."
  redirect "/"
end