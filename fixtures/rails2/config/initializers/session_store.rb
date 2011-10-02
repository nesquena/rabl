# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_rails2_session',
  :secret      => 'b2d31ab1f626a19684aee969cb099d7ab2824150dae712c1c69aaf421bbce2ceb9c2ae85ea9f213440e6baa8e6029f75cebe80fa3af2de8309f885e5f646e8a8'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
