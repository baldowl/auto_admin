require File.dirname(__FILE__) + '/test_helper'

class ConfigurationTest < Test::Unit::TestCase
  def setup
    reset!
    disallow_class_creation!
  end
  def test_dummy; end
end
class ConfigurationEditTest < ConfigurationTest
  def test_default_columns_for_edit
    standard_columns = Film.default_columns_for_edit
    assoc_columns = standard_columns.slice!(-3, 3).sort
    assert_equal %w(title description rental_duration rental_rate length replacement_cost rating), standard_columns
    assert_equal %w(actors category features), assoc_columns
  end
  def test_default_fieldset
    assert_equal 1, Film.admin_fieldsets.size
    fieldset = Film.admin_fieldsets.first
    assert_equal '', fieldset.name
    #FIXME
    #assert_equal Film.default_columns_for_edit, fieldset.fields
    assert_equal :input, fieldset.fieldset_type
  end
  def test_custom_fieldset
    Film.admin_fieldset '', :title, :description, :length
    Film.admin_fieldset 'Rental', :rental_duration, :rental_rate, :replacement_cost
    assert_equal 2, Film.admin_fieldsets.size
    basic, rental = Film.admin_fieldsets
    assert_equal '', basic.name
    #FIXME
    #assert_equal %w(title description length), basic.fields
    assert_equal 'Rental', rental.name
    #FIXME
    #assert_equal %w(rental_duration rental_rate replacement_cost), rental.fields
  end
  def test_child_table
    Country.admin_fieldset '', :country
    Country.admin_child_table 'Cities', :cities do |t|
      t.add_field :city
    end
    assert_equal 2, Country.admin_fieldsets.size
    cities = Country.admin_fieldsets.last
    assert_equal 'Cities', cities.name
    assert_equal :cities, cities.field
    #FIXME
    #assert_equal ['city'], cities.fields
  end
  def test_child_form
    Country.admin_fieldset '', :country
    Country.admin_child_form :cities do |t|
      t.add_field :city
    end
    assert_equal 2, Country.admin_fieldsets.size
    cities = Country.admin_fieldsets.last
    assert_equal :cities, cities.field
    #FIXME
    #assert_equal ['city'], cities.fields
  end
end
class ConfigurationIndexTest < ConfigurationTest
  def test_object_group
    assert_equal '', Address.object_group
    Address.object_group 'Address'
    assert_equal 'Address', Address.object_group
  end
  def test_grouped_objects
    AutoAdmin::AutoAdminConfiguration.primary_objects = [ :address, :customer, :city, :country, :staff_member, :store, :payment, :rental, :film, :actor ]
    expected_groups = ['', 'Clients', 'Internal', 'Transactions']
    expected_groupings = [[Actor, Film], [Address, City, Country, Customer], [StaffMember, Store], [Payment, Rental]]
    Address.object_group 'Clients'
    Customer.object_group 'Clients'
    City.object_group 'Clients'
    Country.object_group 'Clients'
    StaffMember.object_group 'Internal'
    Store.object_group 'Internal'
    Payment.object_group 'Transactions'
    Rental.object_group 'Transactions'
    Feature.object_group 'Other'
    i = 0
    AutoAdmin::AutoAdminConfiguration.grouped_objects do |label, objects|
      assert_equal expected_groups[i], label
      assert_equal expected_groupings[i], objects
      i += 1
    end
    assert_equal 4, i
  end
  def test_primary_objects
    assert_equal [], AutoAdmin::AutoAdminConfiguration.primary_objects
    AutoAdmin::AutoAdminConfiguration.primary_objects = [ :address, :city, :country ]
    assert_equal [ :address, :city, :country ], AutoAdmin::AutoAdminConfiguration.primary_objects
  end
end
class ConfigurationListTest < ConfigurationTest
  def test_default_search_blank
    assert_equal [], Film.columns_for_search, "Model shouldn't has any columns to search before being told how to search"
    assert !Film.respond_to?( :search ), "Model shouldn't respond to search before being told how to search"
  end
  def test_search_by_one
    Film.search_by :title
    assert_equal [:title], Film.columns_for_search, "Model should have a column to search after being told how to search"
    assert Film.respond_to?( :search ), "Model should respond to search after being told how to search"
  end
  def test_search_by_two
    Actor.search_by :first_name, :last_name
    assert_equal [:first_name, :last_name], Actor.columns_for_search, "Model should have columns to search after being told how to search"
    assert Actor.respond_to?( :search ), "Model should respond to search after being told how to search"
  end
  def test_default_search_by_name
    todo!
  end

  def test_default_sort_interface
    assert_equal( { :column => 'name', :reverse => false }, Feature.default_sort_info )
    assert_equal 'name', Feature.sort_column, "Model should sort by default column unless told otherwise"
    assert_equal false, Feature.sort_reverse, "Model should use default sort direction unless told otherwise"
  end
  def test_sort_interface
    Film.sort_by :name, true
    assert_equal 'name', Film.sort_column
    assert_equal true, Film.sort_reverse

    Film.sort_by :length
    assert_equal 'length', Film.sort_column
    assert_equal false, Film.sort_reverse
  end

  def test_default_sort_by_two
    todo!
  end
  def test_sort_by_two
    todo!
  end


  def test_filter_options_for
    assert_equal [], Film.columns_for_filter
    Film.filter_by :rating
    Film.filter_options_for :rating, 'A' => 'X', 'B' => 'Y', 'C' => 'Z'
    assert_equal [:rating], Film.columns_for_filter
    assert_equal( { 'rating' => '*' }, Film.filter_defaults )
    assert_equal ['rating = ?', 'B'], Film.filter_conditions( :rating => 'B' )
  end
  def test_filter_options_for_with_custom_sql_builder
    assert_equal [], Film.columns_for_filter
    Film.filter_by :length
    Film.filter_options_for( :length, '0-60' => 'Very Short', '60-120' => 'Short', '120-999' => 'Long' ) do |val|
      ["length BETWEEN ? AND ?", *( val.split('-').map {|n| n.to_i } )]
    end
    assert_equal [:length], Film.columns_for_filter
    assert_equal( { 'length' => '*' }, Film.filter_defaults )
    assert_equal ['length BETWEEN ? AND ?', 0, 60], Film.filter_conditions( :length => '0-60' )
  end
  def test_filter_by_string
    assert_equal [], Film.columns_for_filter
    Film.filter_by :rating
    assert_equal [:rating], Film.columns_for_filter
    assert_equal( { 'rating' => '*' }, Film.filter_defaults )
  end
  def test_filter_by_string_with_default
    assert_equal [], Film.columns_for_filter
    Film.filter_by :rating
    Film.default_filter :rating => 'NC-17'
    assert_equal [:rating], Film.columns_for_filter
    assert_equal( { 'rating' => 'NC-17' }, Film.filter_defaults )
    assert_equal ['rating = ?', 'NC-17'], Film.filter_conditions( {} )
    assert_equal ['rating = ?', 'PG'], Film.filter_conditions( :rating => 'PG' )
    assert_equal 195, Film.count( :conditions => Film.filter_conditions( :rating => 'R' ) )
  end
  def test_filter_by_date
    assert_equal [], Rental.columns_for_filter
    Rental.filter_by :rent_date
    assert_equal [:rent_date], Rental.columns_for_filter
    assert_equal ['rent_date BETWEEN ? AND ?', 7.days.ago.midnight, Time.now.tomorrow.midnight], Rental.filter_conditions( :rent_date => 'week' )
  end
  def test_filter_by_has_one
    to_test!
  end
  def test_filter_by_belongs_to
    countries = Country.find(:all, :include => :cities, :limit => 5)
    City.filter_by :country
    countries.each do |country|
      assert_equal ['country_id = ?', country.id], City.filter_conditions( :country => country.id )
      assert_equal country.cities.count, City.count( :all, :conditions => City.filter_conditions( :country => country.id ) )
    end
  end
  def test_filter_by_boolean
    Customer.filter_by :active
    assert_equal ['active = ?', true], Customer.filter_conditions( :active => 'true' )
    assert_equal 15, Customer.count( :all, :conditions => Customer.filter_conditions( :active => 'false' ) )
  end
  def test_filter_by_float_just_has_all
    Payment.filter_by :amount
    assert_nil Payment.filter_conditions( :amount => '*' )
    assert_equal 16088, Payment.count( :conditions => Payment.filter_conditions( :amount => '*' ) )
  end

  def test_filter_by_string_and_string_and_belongs_to
    Address.filter_by :district, :postal_code, :city
    Address.default_filter :district => 'QLD'
    assert_equal ['district = ? AND city_id = ?', 'QLD', 7], Address.filter_conditions( :city => 7 )
    assert_equal ['district = ? AND postal_code = ? AND city_id = ?', 'QLD', '123', 9], Address.filter_conditions( :city => 9, :postal_code => '123' )
    assert_equal ['district = ?', 'QLD'], Address.filter_conditions( {} )
    assert_equal 2, Address.count( :conditions => Address.filter_conditions( {} ) )
  end


  def test_default_list_columns
    assert_equal %w{ address address2 district postal_code phone }, Address.default_columns_for_list
  end
  def test_specified_list_columns
    cols = [:address, :address2, :city, :postal_code, :district]
    Address.list_columns *cols
    #assert_equal cols, Address.columns_for_list
  end
  def test_default_list_column_labels
    assert_equal 'Address', Address.column_label( 'address' )
    assert_equal 'Postal code', Address.column_label( 'postal_code' )
    assert_equal 'Phone', Address.column_label( 'phone' )
  end
  def test_specified_list_column_labels
    Address.column_labels :address => 'Address', :phone => 'Phone #'
    assert_equal 'Phone #', Address.column_label( 'phone' ), 'Explicitly set label'
    assert_equal 'Phone #', Address.column_label( :phone ), 'Explicitly set label, accessed as symbol'
    assert_equal 'Address', Address.column_label( 'address' ), 'Explicitly set to default'
    assert_equal 'Postal code', Address.column_label( 'postal_code' ), 'Unspecified label falls through to default'
  end
end

