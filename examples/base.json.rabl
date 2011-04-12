# See 'inherited' for an example of how to extend this template

# Include these three attributes
attributes :title, :kind, :id

child @users do
  attributes :full_name, :first_name
end