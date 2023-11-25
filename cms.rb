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
    render_markdown(content)
  end
end

get '/' do

  erb :index
end

get '/:filename' do
  file_path = @root + "/data/" + params[:filename]

  if @files.include?("#{params[:filename]}")
    load_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect '/'
  end
end

get '/:filename/edit' do
  @filename = params[:filename]
  file_path = @root + "/data/" + params[:filename]
  @content = File.read(file_path)

  erb :edit
end

post '/:filename/edit' do
  file_path = @root + "/data/" + params[:filename]

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been successfully updated."
  redirect "/"
end