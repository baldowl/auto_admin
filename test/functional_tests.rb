require File.dirname(__FILE__) + '/test_helper'

module FunctionTests
module StandardSetup
  def standard_setup
    reset!
    @controller = AutoAdminController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @fred = DummyUser.register_user( DummyUser.new('fred', 'xyzzy') )
  end
  alias setup standard_setup
end

class AuthenticationTest < Test::Unit::TestCase
  include StandardSetup
  def test_doesnt_redirect_when_authenticated
    with_empty_classes :User do
      fake_user = Struct.new( :name ).new( 'Fred Smythe' )
      get :index, {}, { :user => fake_user }
      assert_response :success
    end
  end
  def test_redirects_unless_authenticated
    with_empty_classes :User do
      get :index
      assert_redirected_to :action => 'login'
    end
  end
  def test_login_with_bad_username
    with_dummy_classes :User do
      post :login, :username => 'frank', :password => 'xyzzy'
      assert_nil session[:user]
      assert_response :success
    end
  end
  def test_login_with_bad_password
    with_dummy_classes :User do
      post :login, :username => 'fred', :password => 'hackhack'
      assert_nil session[:user]
      assert_response :success
    end
  end
  def test_login_with_good_details
    with_dummy_classes :User do
      post :login, :username => 'fred', :password => 'xyzzy'
      assert_equal @fred, session[:user]
      assert_redirected_to :action => 'index'
    end
  end
  def test_logout
    get :logout, {}, { :user => @fred }
    assert_nil session[:user]
    assert_redirected_to :action => 'index'
  end
end

class EditTest < Test::Unit::TestCase
  include StandardSetup
  def test_assigns_with_id
    get :edit, :model => 'actor', :id => 3
    assert_equal 3, assigns['object'].id
    assert !assigns['object'].new_record?
  end
  def test_assigns_with_new
    get :edit, :model => 'actor'
    assert assigns['object'].new_record?
  end
  def test_inputs_on_city_edit
    Country.class_eval do
      def to_label; country; end
    end
    get :edit, :model => 'city', :id => 3
    assert_tag :tag => 'input', :attributes => { :id => 'city_city', :name => 'city[city]' }
    assert_tag :tag => 'select', :children => { :count => 109 }, 
      :child => { :tag => 'option', :child => { :content => 'Saint Vincent and the Grenadines' }, :attributes => { :value => '81' } }, 
      :attributes => { :id => 'city_country', :name => 'city[country]' }
  end
  def test_django_text_input_naming
    AutoAdmin::AutoAdminConfiguration.theme = :django
    Actor.admin_fieldset do |f|
      f.auto_field :last_name
      f.text_field :first_name, :required => true
    end
    get :edit, :model => 'actor', :id => 3
    assert_tag :tag => 'fieldset', :attributes => { :class => 'module aligned' }
    assert_tag :tag => 'label', :child => { :content => 'First name:' }, :attributes => { :for => 'actor_first_name', :class => 'required' }
    assert_tag :tag => 'input', :attributes => { :id => 'actor_first_name', :name => 'actor[first_name]', :size => 30, :class => 'vTextField required' }
  end

  def test_boolean_as_auto
    AutoAdmin::AutoAdminConfiguration.theme = :django
    Customer.admin_fieldset do |f|
      f.auto_field :store
      f.auto_field :first_name
      f.auto_field :last_name
      f.auto_field :active
    end

    get :edit, :model => 'customer', :id => 15
    assert_tag :tag => 'input', :attributes => { :checked => true, :id => 'customer_active_true', :name => 'customer[active]', :value => 'true' }
    assert_tag :tag => 'input', :attributes => { :checked => false, :id => 'customer_active_false', :name => 'customer[active]', :value => 'false' }
    assert_tag :tag => 'div', :child => { :content => ' True ' }
    assert_tag :tag => 'div', :child => { :content => ' False' }

    get :edit, :model => 'customer', :id => 16
    assert_tag :tag => 'input', :attributes => { :checked => true, :id => 'customer_active_false', :name => 'customer[active]', :value => 'false' }
  end
  def test_boolean_as_select
    AutoAdmin::AutoAdminConfiguration.theme = :django
    Customer.admin_fieldset do |f|
      f.auto_field :store
      f.auto_field :first_name
      f.auto_field :last_name
      f.select :active
    end

    get :edit, :model => 'customer', :id => 15
    assert_tag :tag => 'select', :children => { :count => 2 }, 
      :child => { :tag => 'option', :child => { :content => 'True' }, :attributes => { :value => 'true', :selected => true } }, 
      :attributes => { :id => 'customer_active', :name => 'customer[active]' }
    assert_tag :tag => 'option', :child => { :content => 'False' }, :attributes => { :value => 'false', :selected => false }

    get :edit, :model => 'customer', :id => 16
    assert_tag :tag => 'option', :child => { :content => 'False' }, :attributes => { :value => 'false', :selected => true }
  end
  def test_boolean_as_check_box
    AutoAdmin::AutoAdminConfiguration.theme = :django
    Customer.admin_fieldset do |f|
      f.auto_field :store
      f.auto_field :first_name
      f.auto_field :last_name
      f.check_box :active
    end

    get :edit, :model => 'customer', :id => 15
    assert_tag :tag => 'input', :attributes => { :checked => true, :id => 'customer_active', :name => 'customer[active]', :value => '1' }

    get :edit, :model => 'customer', :id => 16
    assert_tag :tag => 'input', :attributes => { :checked => false, :id => 'customer_active', :name => 'customer[active]', :value => '1' }
  end
  def test_boolean_as_radio_group
    AutoAdmin::AutoAdminConfiguration.theme = :django
    Customer.admin_fieldset do |f|
      f.auto_field :store
      f.auto_field :first_name
      f.auto_field :last_name
      f.radio_group :active
    end

    get :edit, :model => 'customer', :id => 15
    assert_tag :tag => 'input', :attributes => { :checked => true, :id => 'customer_active_true', :name => 'customer[active]', :value => 'true' }
    assert_tag :tag => 'input', :attributes => { :checked => false, :id => 'customer_active_false', :name => 'customer[active]', :value => 'false' }

    get :edit, :model => 'customer', :id => 16
    assert_tag :tag => 'input', :attributes => { :checked => true, :id => 'customer_active_false', :name => 'customer[active]', :value => 'false' }
  end
  def test_boolean_as_customised_radio_group
    AutoAdmin::AutoAdminConfiguration.theme = :django
    Customer.admin_fieldset do |f|
      f.auto_field :store
      f.auto_field :first_name
      f.auto_field :last_name
      f.radio_group :active, :choices => ['Active', 'Suspended']
    end

    get :edit, :model => 'customer', :id => 15
    assert_tag :tag => 'input', :attributes => { :checked => true, :id => 'customer_active_true', :name => 'customer[active]', :value => 'true' }
    assert_tag :tag => 'input', :attributes => { :checked => false, :id => 'customer_active_false', :name => 'customer[active]', :value => 'false' }
    assert_tag :tag => 'div', :child => { :content => ' Active ' }
    assert_tag :tag => 'div', :child => { :content => ' Suspended' }

    get :edit, :model => 'customer', :id => 16
    assert_tag :tag => 'input', :attributes => { :checked => true, :id => 'customer_active_false', :name => 'customer[active]', :value => 'false' }
  end
end

class ListTest < Test::Unit::TestCase
  include StandardSetup
  def test_trivial_list
    AutoAdmin::AutoAdminConfiguration.theme = :django
    get :list, { :model => 'category' }
    assert_response :success
    assert_tag :tag => 'table', :attributes => { :cellspacing => '0' }
  end
  def test_list_saves_params
    Actor.search_by :last_name
    get :list, { 'model' => 'actor', 'search' => 'MAN' }
    assert_equal( { 'controller' => 'auto_admin', 'action' => 'list', 'model' => 'actor', 'sort' => nil, 'sort_reverse' => false, 'search' => 'MAN', 'filter' => {} }, session[:admin_list_params]['actor'] )
  end
  def test_filtered_list
    StaffMember.filter_by :store
    get :list, { 'model' => 'staff_member', 'filter' => { 'store' => '2' } }
    assert_response :success
    assert_equal 1, assigns['objects'].size
  end
  def test_sorted_list
    get :list, { 'model' => 'staff_member', 'sort' => 'last_name', 'sort_reverse' => 'true' }
    assert_response :success
    assert_equal( %w(Stephens Hillyer), assigns['objects'].map {|o| o.last_name } )

    get :list, { 'model' => 'staff_member', 'sort' => 'last_name' }
    assert_response :success
    assert_equal( %w(Hillyer Stephens), assigns['objects'].map {|o| o.last_name } )
  end
  def test_searched_list
    Actor.search_by :last_name
    get :list, { 'model' => 'actor', 'search' => 'MAN' }
    assert_response :success
    assert_equal 10, assigns['objects'].size
  end
  def test_paginated_list
    get :list, { 'model' => 'customer', 'sort' => 'last_name', 'per_page' => '50', 'page' => '2' }
    assert_response :success
    assert_equal 50, assigns['objects'].size
    assert_equal( %w(CAROLINE BYRON EMMA ANA TED VICKIE RUSSELL BEVERLY CHRIS ELIZABETH), 
      assigns['objects'][0...10].map {|o| o.first_name } )
    assert_tag :tag => 'span', :attributes => { :class => 'this-page' }, :child => { :content => '2' }
    assert_tag :tag => 'a', :attributes => { :href => /page=4/ }, :child => { :content => '4' }
    assert_tag :tag => 'a', :attributes => { :href => /page=12/, :class => 'end' }, :child => { :content => '12' }
  end
  def test_paginated_list_with_twenty
    get :list, { 'model' => 'customer', 'sort' => 'last_name', 'per_page' => '20' }
    assert_response :success
    assert_equal 20, assigns['objects'].size
  end
end

class SaveTest < Test::Unit::TestCase
  include StandardSetup
  def test_save_with_belongs_to
    Customer.class_eval do
      def to_label; "#{first_name} #{last_name}"; end
    end
    post :save, { 'model' => 'customer', 'id' => '13', 'customer' => { 'store' => '1' } }
    assert_response :redirect
    get :edit, :model => 'customer', :id => 13
    assert_response :success
    assert_tag :tag => 'select', :attributes => { :id => 'customer_store', :name => 'customer[store]' }, :children => { :count => 2 },
      :child => { :tag => 'option', :attributes => { :selected => true, :value => '1' } }
    assert_tag :content => 'The customer &quot;KAREN JACKSON&quot; was changed successfully. '

    post :save, { 'model' => 'customer', 'id' => '13', 'customer' => { 'store' => '2' } }
    assert_response :redirect
    get :edit, :model => 'customer', :id => 13
    assert_response :success
    assert_tag :tag => 'select', :attributes => { :id => 'customer_store', :name => 'customer[store]' }, :children => { :count => 2 },
      :child => { :tag => 'option', :attributes => { :selected => true, :value => '2' } }
  end
  def test_save_with_belongs_to_under_django
    AutoAdmin::AutoAdminConfiguration.theme = :django
    Customer.class_eval do
      def to_label; "#{first_name} #{last_name}"; end
    end
    post :save, { 'model' => 'customer', 'id' => '13', 'customer' => { 'store' => '1' } }
    assert_response :redirect
    get :edit, :model => 'customer', :id => 13
    assert_response :success
    assert_tag :tag => 'select', :attributes => { :id => 'customer_store', :name => 'customer[store]' }, :children => { :count => 2 },
      :child => { :tag => 'option', :attributes => { :selected => true, :value => '1' } }
    assert_tag :content => 'The customer &quot;KAREN JACKSON&quot; was changed successfully. '

    post :save, { 'model' => 'customer', 'id' => '13', 'customer' => { 'store' => '2' } }
    assert_response :redirect
    get :edit, :model => 'customer', :id => 13
    assert_response :success
    assert_tag :tag => 'select', :attributes => { :id => 'customer_store', :name => 'customer[store]' }, :children => { :count => 2 },
      :child => { :tag => 'option', :attributes => { :selected => true, :value => '2' } }
  end
end

#class HistoryTest < Test::Unit::TestCase
#  include StandardSetup
#end

#class DeleteTest < Test::Unit::TestCase
#  include StandardSetup
#end

end # FunctionalTests

