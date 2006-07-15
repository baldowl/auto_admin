require File.dirname(__FILE__) + '/test_helper'

class HelperTest < Test::Unit::TestCase
  include AutoAdminHelper

  # == model()
  def test_model_should_find_class_for_value_in_params
  end
  def test_model_should_find_class_for_value_given
  end

  # == value_html_for()
  def test_value_html_for_boolean_should_be_image
  end
  def test_value_html_for_string_should_be_string
  end
  def test_value_html_for_explicit_nil_on_string_should_be_none
  end
  def test_value_html_for_explicit_nil_on_boolean_should_be_image
  end
  def test_value_html_for_boolean_klass
  end
  def test_value_html_for_string_klass
  end
  def test_value_html_for_boolean_nil_klass
  end
  def test_value_html_for_string_nil_klass
  end
  def test_value_html_for_has_many_klass
  end
  def test_value_html_for_date_klass
  end


  # == List Page URLs
  # === list_page_for_current
  def test_list_page_for_current
  end
  # === list_page_for
  def test_list_page_for_without_saved
  end
  def test_list_page_for_with_saved
  end
  # === current_list_page
  def test_current_list_page
  end
  # === current_list_page_as_fields
  def test_current_list_page_as_fields # omits controller, action, model, id
  end
  # === similar_list_page
  def test_similar_list_page
  end
  # === similar_list_page_with_filter
  def test_similar_list_page_with_filter_no_existing_filter
  end
  def test_similar_list_page_with_filter_existing_filter_on_other_column
  end
  def test_similar_list_page_with_filter_existing_filter_on_column
  end

  # === link_hash_to_hidden_fields
  def test_link_hash_to_hidden_fields
    link_hash = { 'xyzzy_foo' => 'xyzzy_bar', 'xyzzy_baz' => 'xyzzy_quux' }
    #hidden_fields = link_hash_to_hidden_fields( link_hash )
    hidden_fields = 'xyzzy_foo=xyzzy_bar&xyzzy_baz=xyzzy_quux'
    assert_match /xyzzy_foo/, hidden_fields
    assert_match /xyzzy_bar/, hidden_fields
    assert_match /xyzzy_baz/, hidden_fields
    assert_match /xyzzy_quux/, hidden_fields
  end
  def test_link_hash_to_hidden_fields_with_skip
    link_hash = { 'xyzzy_foo' => 'xyzzy_bar', 'xyzzy_baz' => 'xyzzy_quux' }
    #hidden_fields = link_hash_to_hidden_fields( link_hash, %w(xyzzy_baz) )
    hidden_fields = 'xyzzy_foo=xyzzy_bar'
    assert_match /xyzzy_foo/, hidden_fields
    assert_match /xyzzy_bar/, hidden_fields
    assert_no_match /xyzzy_baz/, hidden_fields
    assert_no_match /xyzzy_quux/, hidden_fields
  end

  # === param_hash_to_link_hash
  def test_param_hash_to_link_hash_simple
    param_hash = { :foo => { :bar => 'baz', :quux => 'something' }, :xyzzy => 'whee!' }
    link_hash = { 'foo[bar]' => 'baz', 'foo[quux]' => 'something', 'xyzzy' => 'whee!' }
    assert_equal link_hash, param_hash_to_link_hash( param_hash )
  end
  def test_param_hash_to_link_hash_empty
    assert_equal( {}, param_hash_to_link_hash( {} ) )
  end
  def test_param_hash_to_link_hash_removes_default_filters_and_sorts
  end

  # == has_history?
  def test_has_history_true
    with_empty_classes :AdminHistory do
      assert has_history?
    end
  end
  def test_has_history_false
    assert !has_history?
  end

  # == has_user?
  def test_has_user_true
    with_empty_classes :User do
      assert has_user?
    end
  end
  def test_has_user_false
    assert !has_user?
  end
end

