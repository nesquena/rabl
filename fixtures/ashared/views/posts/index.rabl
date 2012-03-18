collection @posts => :articles
cache ['kittens!', @posts]

extends "posts/show"

node(:created_by_admin, :if => lambda { |p| p.user.is_admin }) do |p|
  true
end

child({ :user => :admin }, { :if => lambda { |p| p.user.is_admin  }}) do |p|
  extends "users/show"
end