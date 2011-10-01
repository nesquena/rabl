require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')

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
      get "/posts"
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
  end

  context "for show action" do
    setup do
      get "/posts/#{@post1.id}"
    end

     # Attributes (regular)
    asserts("contains post title") { json_output['post']['title'] }.equals { @post1.title }
    asserts("contains post body")  { json_output['post']['body'] }.equals { @post1.body }

    # Attributes (custom name)
    asserts("contains post posted_at") { json_output['post']['posted_at'] }.equals { @post1.created_at.iso8601 }

    # Child
    asserts("contains post user child username") { json_output["post"]["user"]["username"] }.equals { @post1.user.username }
    asserts("contains post user child role") { json_output["post"]["user"]["role"] }.equals { "normal" }

    # Child Numbers of the Child User
    asserts("contains post user child numbers") do
      json_output["post"]["user"]["pnumbers"][0]["pnumber"]["formatted"]
    end.equals { @post1.user.phone_numbers[0].formatted }

    # Glue (username to article)
    asserts("contains glued username") { json_output['post']["author_name"] }.equals { @post1.user.username }
  end
end
