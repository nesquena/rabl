object @post

attributes :title, :body
attributes :created_at => :posted_at

child :user do
  extends "users/show"
end

glue :user do
  attributes :username => :author_name
end