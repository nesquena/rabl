object @post

attribute :title => :title_v1

child :user do
  extends "users/show"
end
