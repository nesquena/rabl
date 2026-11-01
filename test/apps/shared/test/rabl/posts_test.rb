require_relative '../rabl_helper'

class PostsTest < RablAppTest
  def setup
    create_posts!
  end

  def articles
    json_output['articles'].map { |o| o['article'] }
  end

  # posts/index: a named collection that extends posts/show, with a conditional node and child
  def test_index
    get "/posts", :format => :json

    assert_equal @posts.map(&:title), articles.map { |a| a['title'] }
    assert_equal @posts.map(&:body), articles.map { |a| a['body'] }
    assert_equal @posts.map { |p| p.created_at.to_i }, articles.map { |a| Time.parse(a['posted_at']).to_i }
    assert_equal @posts.map { |p| p.user.username }, articles.map { |a| a['user']['username'] }
    assert_equal %w(normal normal admin), articles.map { |a| a['user']['role'] }
    assert_equal @posts.map { |p| p.user.phone_numbers.first.formatted }, articles.map { |a| a['user']['pnumbers'][0]['pnumber']['formatted'] }
    assert_equal @posts.map { |p| p.user.username }, articles.map { |a| a['author_name'] }
    assert_equal [@user3.username], articles.map { |a| a['admin']['username'] if a.key?('admin') }.compact
    assert_equal true, articles.last['created_by_admin']
    refute articles.first.key?('created_by_admin')
  end

  def test_show
    get "/posts/#{@post1.id}", :format => :json
    post = json_output['post']

    assert_equal @post1.title, post['title']
    assert_equal @post1.body, post['body']
    assert_equal @post1.created_at.to_i, Time.parse(post['posted_at']).to_i
    assert_equal @post1.user.username, post['user']['username']
    assert_equal 'normal', post['user']['role']
    assert_equal @post1.user.phone_numbers[0].formatted, post['user']['pnumbers'][0]['pnumber']['formatted']
    assert_equal @post1.user.username, post['author_name']
    # a partial rendering a non-ORM object (the Time)
    assert_equal @post1.created_at.day, post['created_date']['day']
    assert_equal @post1.created_at.hour, post['created_date']['hour']
    assert_equal @post1.created_at.iso8601, post['created_date']['full']
    # a helper of the app
    assert_equal 'BAR!', post['foo']
    assert_equal [@post1.title, @post1.body], post['post']
  end

  def test_escape_all_output
    Rabl.configuration.escape_all_output = true
    get "/posts/#{@post1.id}", :format => :json
    assert_equal @post1.body, json_output['post']['body']

    get "/posts/#{@post3.id}", :format => :json
    assert_equal ERB::Util.h(@post3.body), json_output['post']['body']
  ensure
    Rabl.configuration.escape_all_output = false
  end

  # Rabl.render with the app as the scope, and a partial in a node
  def test_renderer
    with_caching { get "/posts/#{@post1.id}/renderer" }
    post = json_output['post']

    assert_equal [@post1.title, @post1.body], [post['title'], post['body']]
    assert_equal [@post1.title, @post1.body], [post['partial']['title'], post['partial']['body']]
  end

  def test_cached_index_and_show_are_served_from_the_cache
    with_caching do
      get "/posts", :format => :json
      get "/posts/#{@post1.id}", :format => :json
      Post.update_all(:title => "changed") # leaves the cache keys (and updated_at) alone

      get "/posts", :format => :json
      assert_equal @posts.map(&:title), articles.map { |a| a['title'] }
      get "/posts/#{@post1.id}", :format => :json
      assert_equal @post1.title, json_output['post']['title']
    end

    get "/posts/#{@post1.id}", :format => :json
    assert_equal "changed", json_output['post']['title']
  end
end
