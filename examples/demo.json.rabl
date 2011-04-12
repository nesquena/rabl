# Use the @media object set in route
object @media

# Include these three attributes
attributes :title, :kind, :id
# Rename 'studio' to be the 'company' node
attributes :studio => :company

# Arbitrary code blocks can be defined
# Creates a 'release_year' node
code :release_year do |m|
  date = m.release_date || m.series_start
  date.try(:year)
end

# Creates a node 'users' with an array of the nested users for media
# Block is the same rabl syntax for the sub object
child @users do
  attributes :full_name, :first_name
end

# Uses the associations of the parent media object
# Rename 'users' association to 'people' node
child :users => :people do
  attributes :full_name, :first_name
end

# Creates the "actor" association as a 'user' node
# Use the information from another rabl template to describe the representation
child :actor => :user do
  extends "users/simple"
end

# Append attributes to the root node with prefixed names
glue @users.first do
  attributes :full_name => :user_full_name, :first_name => :user_first_name
end

# Render an arbitrary hash with a partial rabl json as one of the keys
code :topics do |m|
  { :fake => partial("media/user", :object => @users.first), :raw => @users.first }
end