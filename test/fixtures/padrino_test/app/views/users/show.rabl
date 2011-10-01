object @user

attributes :username, :email, :location
attributes :created_at => :registered_at

node :role do |user|
  user.is_admin ? 'admin' : 'normal'
end

child :phone_numbers => :pnumbers do
  extends "users/phone_number"
end