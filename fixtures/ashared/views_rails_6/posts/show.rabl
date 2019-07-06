object @post
cache @post

attributes :title, :body
attributes :created_at => :posted_at

child :user do
  extends "users/show"
end

glue :user do
  attributes :username => :author_name
end

code(:created_date) do |p|
  partial("posts/date", :object => p.created_at)
end

node(:post) do |post|
  [post.title, post.body]
end

node(:foo) { helper_foo }

node(:created_at_in_words) {|p| time_ago_in_words(p.created_at) }
