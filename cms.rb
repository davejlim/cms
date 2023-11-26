require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'

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

def signed_in?
  session[:signed_in]
end

def sign_in_message
  session[:message] = "You must be signed in to do that."
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def authenticate(username, password)
  credentials = load_user_credentials
  
  credentials.key?(username) && credentials[username] == password
end

get '/' do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end

  erb :index
end

get '/new' do
  if signed_in?
    erb :new
  else
    sign_in_message
    redirect '/'
  end
end

post '/create' do
  if signed_in?
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
  else
    sign_in_message
    erb :new
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
  if signed_in?
    @filename = params[:filename]
    file_path = File.join(data_path, @filename)
    @content = File.read(file_path)

    erb :edit
  else
    sign_in_message
    redirect '/'
  end
end

post '/:filename/edit' do
  if signed_in?
    file_path = @root + "/data/" + params[:filename]

    File.write(file_path, params[:content])

    session[:message] = "#{params[:filename]} has been successfully updated."
    redirect "/"
  else
    sign_in_message
    erb :edit
  end
end

post '/:filename/delete' do
  if signed_in?
    @filename = params[:filename]
    file_path = File.join(data_path, @filename)

    File.delete(file_path)

    session[:message] = "#{params[:filename]} has been successfully deleted."
    redirect "/"
  else
    sign_in_message
    redirect "/"
  end
end

get '/users/signin' do
  erb :signin
end

post '/users/signin' do
  if authenticate(params[:username], params[:password])
    session[:signed_in] = true
    session[:username] = params[:username]
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid credentials!"
    status 422
    erb :signin
  end
end

post '/signout' do
  session[:signed_in] = false
  session[:username] = nil
  session[:message] = "You have been signed out."
  redirect "/"
end
