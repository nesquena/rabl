object @post

attribute :title => :title_v1

child :user do
  extends "users/show"
end

node(:created_at_in_words) { |p| time_ago_in_words(p.created_at) }
