ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content= "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  # Method to access session object
  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin", signed_in: true } }
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_history
    create_document "history.txt", "history"

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_equal "history", last_response.body
  end

  def test_wrong_name
    get "/fake.txt"
    assert_equal 302, last_response.status
    
    assert_equal "fake.txt does not exist.", session[:message]
  end

  def test_markdown
    create_document "about.md", "# Ruby is..."

    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_editing_document
    create_document "changes.txt"

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<input type="submit")
  end


  def test_editing_document
    create_document "changes.txt"

    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_updating_document
    post "/changes.txt/edit", {content: "new content"}, admin_session

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been successfully updated.", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end


  def test_updating_document_signed_out
    post "/changes.txt/edit", {content: "new content"}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_view_new_document_form
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(input type="submit")
  end

  def test_create_new_document
    post "/create", {filename: "test.txt"}, admin_session
    
    assert_equal 302, last_response.status
    assert_equal "test.txt has been created.", session[:message]

    get "/"
    assert_includes last_response.body, "test.txt"
  end

  def test_create_new_document_signed_out
    post "/create", {filename: "test.txt"}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_document_without_filename
    post "/create", {filename: ""}, admin_session

    assert_equal 422, last_response.status
    assert_equal "A name is required.", session[:message]
  end

  def test_delete_document
    create_document "test.txt"

    post "/test.txt/delete", {}, admin_session

    assert_equal 302, last_response.status
    assert_equal "test.txt has been successfully deleted.", session[:message]

    get "/"
    refute_includes last_response.body, %q(href="test.txt")
  end

  def test_delete_document_signed_out
    create_document "test.txt"

    post "/test.txt/delete"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_signin_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<input type="submit")
  end

  def test_signin
    post "/users/signin", username: "admin", password: "password"

    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_sign_with_bad_credentials
    post "/users/signin", username: "fake", password: "fake"
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid credentials!"
  end

  def test_signout
    get "/", {}, {"rack.session" => { username: "admin", signed_in: true } }
    assert_includes last_response.body, "Signed in as admin"

    post "/signout"
    assert_equal "You have been signed out.", session[:message]

    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end
end