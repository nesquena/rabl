# Lives in <rabl>/test/integration/posts_controller_test.rb
# Symlinked to fixture applications

begin # Padrino
  require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')
rescue LoadError # Rails
  require File.expand_path(File.dirname(__FILE__) + '/../test_helper.rb')
end

require 'rexml/document'

context "PostsController" do
  helper(:json_output) { JSON.parse(last_response.body) }

  setup do
    create_users!
    Post.delete_all
    @post1 = Post.create(:title => "Foo", :body => "Bar", :user_id => @user1.id)
    @post2 = Post.create(:title => "Baz", :body => "Bah", :user_id => @user2.id)
    @post3 = Post.create(:title => "Kaz", :body => "<script>alert('xss & test');</script>", :user_id => @user3.id)
    @posts = [@post1, @post2, @post3]
  end

  context "for index action" do
    setup do
      get "/posts", format: :json
    end

    # Attributes (regular)
    asserts("contains post titles") do
      json_output['articles'].map { |o| o["article"]["title"] }
    end.equals { @posts.map(&:title) }

    asserts("contains post bodies") do
      json_output['articles'].map { |o| o["article"]["body"] }
    end.equals { @posts.map(&:body) }

    # Attributes (custom name)
    asserts("contains post posted_at") do
      json_output['articles'].map { |o| o["article"]["posted_at"] }
    end.equals { @posts.map(&:created_at).map{ |t| t.iso8601(3) } }

    # Child
    asserts("contains post user child username") do
      json_output['articles'].map { |o| o["article"]["user"]["username"] }
    end.equals { @posts.map(&:user).map(&:username) }

    asserts("contains post user child role") do
      json_output['articles'].map { |o| o["article"]["user"]["role"] }
    end.equals { ["normal", "normal", "admin"] }

    # Child Numbers of the Child User
    asserts("contains post user child numbers") do
      json_output['articles'].map { |o| o["article"]["user"]["pnumbers"][0]["pnumber"]["formatted"] }
    end.equals { @posts.map(&:user).map(&:phone_numbers).map(&:first).map(&:formatted) }

    # Glue (username to article)
    asserts("contains glued usernames") do
      json_output['articles'].map { |o| o["article"]["author_name"] }
    end.equals { @posts.map(&:user).map(&:username) }

    # Conditional Child (admin)
    asserts("contains admin child only for admins") do
      json_output['articles'].map { |o| o["article"]["admin"]["username"] if o["article"].has_key?("admin") }.compact
    end.equals { [@user3.username] }

    # Conditional Node (created_by_admin)
    asserts("contains created_by_admin node for admins") do
      json_output['articles'].last['article']['created_by_admin']
    end.equals { true }

    denies("contains no created_by_admin node for non-admins") do
      json_output['articles'].first['article']
    end.includes(:created_by_admin)
  end # index action, json

  context "escaping output in index action" do
    context "for first post" do
      setup do
        Rabl.configuration.escape_all_output = true
        get "/posts/#{@post1.id}", format: :json
        json_output['post']
      end

      # Attributes (regular)
      asserts("contains post title") { topic['title'] }.equals { @post1.title }
      asserts("contains post body")  { topic['body'] }.equals { @post1.body }
    end

    context "for third post with script tags" do
      setup do
        Rabl.configuration.escape_all_output = true
        get "/posts/#{@post3.id}", format: :json
        json_output['post']
      end

      # Attributes (regular)
      asserts("contains post title") { topic['title'] }.equals { @post3.title }
      asserts("contains escaped post body")  { topic['body'] }.equals { ERB::Util.h(@post3.body) }
    end
  end # escaping output

  context "for show action" do
    setup do
      get "/posts/#{@post1.id}", format: :json
      json_output['post']
    end

    # Attributes (regular)
    asserts("contains post title") { topic['title'] }.equals { @post1.title }
    asserts("contains post body")  { topic['body'] }.equals { @post1.body }

    # Attributes (custom name)
    asserts("contains post posted_at") { topic['posted_at'] }.equals { @post1.created_at.utc.to_s }

    # Child
    asserts("contains post user child username") { topic["user"]["username"] }.equals { @post1.user.username }
    asserts("contains post user child role") { topic["user"]["role"] }.equals { "normal" }

    # Child Numbers of the Child User
    asserts("contains post user child numbers") do
      topic["user"]["pnumbers"][0]["pnumber"]["formatted"]
    end.equals { @post1.user.phone_numbers[0].formatted }

    # Glue (username to article)
    asserts("contains glued username") { topic["author_name"] }.equals { @post1.user.username }

    # Non-ORM Date Node Partial
    context "for date node" do
      setup { json_output['post']['created_date'] }
      asserts("contains date partial with day")   { topic['day'] }.equals { @post1.created_at.day }
      asserts("contains date partial with hour")  { topic['hour'] }.equals { @post1.created_at.hour }
      asserts("contains date partial with full")  { topic['full'] }.equals { @post1.created_at.iso8601 }
    end # date node

    asserts("contains helper action") { topic["foo"] }.equals { "BAR!" }
    denies("contains helper action") { topic["created_at_in_words"] }.nil

    asserts("contains post attributes via node") { topic["post"] }.equals { [@post1.title, @post1.body] }
  end # show action, json

  context "renderer" do
    setup do
      mock(ActionController::Base).perform_caching.any_number_of_times { true }
      get "/posts/#{@post1.id}/renderer"
      json_output['post']
    end

    # Attributes (regular)
    asserts("contains post title") { topic['title'] }.equals { @post1.title }
    asserts("contains post body")  { topic['body'] }.equals { @post1.body }

    # Attributes (partial)
    asserts("contains post partial title") { topic['partial']['title'] }.equals { @post1.title }
    asserts("contains post partial body")  { topic['partial']['body'] }.equals { @post1.body }
  end # renderer action, json

  context "for index action rendering JSON within HTML" do
    setup do
      get "/posts", format: :html
    end

    asserts(:body).includes { "<html>" }
  end # index action, html

  context "for show action rendering JSON within HTML" do
    setup do
      get "/posts/#{@post1.id}", format: :html
    end

    asserts(:body).includes { "<html>" }
  end # show action, html

  context "mime_type" do
    setup do
      get "/posts/#{@post1.id}", format: :rabl_test_v1
    end

    asserts("contains post title") { json_output['post']['title_v1'] }.equals { @post1.title }
    asserts("contains username") { json_output['post']['user']['username_v1'] }.equals { @post1.user.username }
  end

  context "caching" do
    helper(:cache_hit) do |key|
      Rails.cache.read(ActiveSupport::Cache.expand_cache_key(key, :rabl))
    end

    setup do
      mock(ActionController::Base).perform_caching.any_number_of_times { true }
      Rails.cache.clear
    end

    context "for index action with caching in json" do
      setup do
        get "/posts", format: :json
      end

      asserts("contains post titles") do
        json_output['articles'].map { |o| o['article']['title'] }
      end.equals { @posts.map(&:title) }

      asserts(:body).equals { cache_hit ['kittens!', @posts, nil, 'json', 'e83f65eee5ffb454c418a59105f222c4'] }

      asserts("contains cache hits per object (posts by title)") do
        json_output['articles'].map { |o| o['article']['title'] }
      end.equals { @posts.map { |p| cache_hit([p, nil, 'hash', 'e373525f49a3b3b044af05255e84839d'])[:title] } }
    end # index action, caching, json

    context "for index action with caching in xml" do
      setup do
        get "/posts", format: :xml
      end

      asserts("contains post titles") do
        doc = REXML::Document.new topic.body
        doc.elements.inject('articles/article/title', []) {|arr, ele| arr << ele.text}
      end.equals { @posts.map(&:title) }

      asserts(:body).equals { cache_hit ['kittens!', @posts, nil, 'xml', 'e83f65eee5ffb454c418a59105f222c4'] }
    end # index action, caching, xml

    context "for show action with caching" do
      setup do
        get "/posts/#{@post1.id}", format: :json
      end

      asserts("contains post title") { json_output['post']['title'] }.equals { @post1.title }

      asserts(:body).equals { cache_hit [@post1, nil, 'json', 'e373525f49a3b3b044af05255e84839d'] }
    end # show action, caching, json

    context "cache_all_output" do
      helper(:cache_hit) do |key|
        Rails.cache.read(ActiveSupport::Cache.expand_cache_key([key, 'article', 'json'], :rabl))
      end

      setup do
        Rabl.configuration.cache_all_output = true
        get "/posts", format: :json
      end

      asserts("contains cache hits per object (posts by title)") do
        json_output['articles'].map { |o| o['article']['title'] }
      end.equals { @posts.map{ |p| cache_hit(p)['article'][:title] } }
    end  # index action, cache_all_output
  end

end
