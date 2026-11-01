require_relative '../rabl_helper'

class RailsTest < RablAppTest
  def setup
    create_posts!
  end

  # ERB views and their layout rendering rabl templates as JSON
  def test_html_views_render_rabl_templates
    get "/posts", :format => :html
    assert_includes last_response.body, "<html>"
    assert_includes last_response.body, %("title":"Foo")

    get "/posts/#{@post1.id}", :format => :html
    assert_includes last_response.body, "<html>"
    assert_includes last_response.body, %("title":"Foo")
  end

  # A template named for a registered MIME type is used for that format, by the template
  # itself and by the templates it extends
  def test_custom_mime_type
    get "/posts/#{@post1.id}", :format => :rabl_test_v1
    post = json_output['post']

    assert_equal @post1.title, post['title_v1']
    assert_equal @post1.user.username, post['user']['username_v1']
    # a Rails view helper
    assert_equal "less than a minute", post['created_at_in_words']

    get "/posts", :format => :rabl_test_v1
    article = json_output['articles'].first['article']
    assert_equal @post1.title, article['title_v1']
    assert_equal @post1.user.username, article['user']['username_v1']
  end

  def test_xml
    with_caching do
      get "/posts", :format => :xml
      Post.update_all(:title => "changed")
      get "/posts", :format => :xml
    end

    assert last_response.body.start_with?('<?xml'), last_response.body
    titles = last_response.body.scan(%r{<title>([^<]*)</title>}).flatten
    assert_equal @posts.map(&:title), titles
  end

  def test_api_controller
    get "/api/posts/#{@post1.id}", :format => :json
    assert_equal({ "post" => { "title" => "Foo", "user" => { "username" => "billybob" } } }, json_output)
  end
end
