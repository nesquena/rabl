require_relative '../rabl_helper'

class UsersTest < RablAppTest
  def setup
    create_users!
  end

  def people
    json_output.map { |u| u['user'] }
  end

  # users/index: an unnamed collection extending users/show with locals
  def test_index
    get "/users", :format => :json

    assert_equal @users.map(&:username), people.map { |u| u['username'] }
    assert_equal @users.map(&:email), people.map { |u| u['email'] }
    assert_equal @users.map(&:location), people.map { |u| u['location'] }
    assert_equal @users.map { |u| u.created_at.to_i }, people.map { |u| Time.parse(u['registered_at']).to_i }
    assert_equal %w(normal normal admin), people.map { |u| u['role'] }
    assert_equal @users.map { |u| u.phone_numbers.map(&:formatted) }, people.map { |u| u['pnumbers'].map { |n| n['pnumber']['formatted'] } }
    # a partial of a collection in a node, given the locals of the extended template
    assert_equal @users.map { |u| u.phone_numbers.map { |n| n.formatted.reverse } }, people.map { |u| u['node_numbers'].map { |n| n['reversed'] } }
  end

  # users/show: `object @user => :person` names the root
  def test_show
    get "/users/#{@user1.id}", :format => :json
    person = json_output['person']

    assert_equal [@user1.username, @user1.email, @user1.location], person.values_at('username', 'email', 'location')
    assert_equal @user1.created_at.to_i, Time.parse(person['registered_at']).to_i
    assert_equal 'normal', person['role']
    assert_equal @user1.phone_numbers.map(&:formatted), person['pnumbers'].map { |n| n['pnumber']['formatted'] }
    assert_equal @user1.phone_numbers.map(&:formatted), person['node_numbers'].map { |n| n['formatted'] }
  end

  # cache_all_output caches each object of a template that has no `cache` of its own
  def test_cache_all_output
    Rabl.configuration.cache_all_output = true
    with_caching do
      get "/users", :format => :json
      User.update_all(:email => "changed")
      get "/users", :format => :json
      assert_equal @users.map(&:email), people.map { |u| u['email'] }
    end
  ensure
    Rabl.configuration.cache_all_output = false
  end
end
