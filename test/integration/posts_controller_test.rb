# Lives in <rabl>/test/integration/posts_controller_test.rb
# Symlinked to fixture applications

begin # Padrino
  require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')
rescue LoadError # Rails
  require File.expand_path(File.dirname(__FILE__) + '/../test_helper.rb')
end

context "PostsController" do
  helper(:json_output) { JSON.parse(last_response.body) }

  setup do
    create_users!
    Post.delete_all
    @post1 = Post.create(:title => "Foo", :body => "Bar", :user_id => @user1.id)
    @post2 = Post.create(:title => "Baz", :body => "Bah", :user_id => @user2.id)
    @post3 = Post.create(:title => "Kaz", :body => "Paz", :user_id => @user3.id)
    @posts = [@post1, @post2, @post3]
  end

  context "for index action" do
    setup do
      get "/posts", :format => :json
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
    end.equals { @posts.map(&:created_at).map(&:iso8601) }

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
  end # index action

  context "for show action" do
    setup do
      get "/posts/#{@post1.id}", :format => :json
      json_output['post']
    end

     # Attributes (regular)
    asserts("contains post title") { topic['title'] }.equals { @post1.title }
    asserts("contains post body")  { topic['body'] }.equals { @post1.body }

    # Attributes (custom name)
    asserts("contains post posted_at") { topic['posted_at'] }.equals { @post1.created_at.iso8601 }

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
  end # show action
end
