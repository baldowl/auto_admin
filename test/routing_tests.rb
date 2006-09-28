require File.dirname(__FILE__) + '/test_helper'

class AdminRoutingTest < Test::Unit::TestCase
  # Because of relative references in the stylesheet, this route *must*
  # be correct; the browser has to see *path as part of the filename.
  def test_asset
    assert_routing "/admin/asset/stylesheets/auto_admin.css", :controller => 'auto_admin', :action => 'asset', :path => %w(stylesheets auto_admin.css)
  end

  # Things wouldn't look too hot if we didn't get the default page
  # right. 
  def test_index
    assert_routing "/admin", :controller => 'auto_admin', :action => 'index'
  end

  # This function contains a small portion of the contents of
  # assert_generates().
  def url_for options={}, extras={}
    ActionController::Routing::Routes.reload if ActionController::Routing::Routes.empty? 

    generated_path, extra_keys = ActionController::Routing::Routes.generate(options, extras)
    generated_path
  end

  # We don't care what the URLs for the next ones are, as long as
  # whatever it generates can be parsed again.

  # Standard model-less action
  def test_login
    opts = { :controller => 'auto_admin', :action => 'login', :model => nil }
    assert_routing url_for( opts ), opts
  end

  # Model without ID (default action)
  def test_list
    opts = { :controller => 'auto_admin', :action => 'list', :model => 'user', :id => nil }
    assert_routing url_for( opts ), opts
  end

  # Model with ID (default action)
  def test_edit
    opts = { :controller => 'auto_admin', :action => 'edit', :model => 'user', :id => '7' }
    assert_routing url_for( opts ), opts
  end

  # Model with ID (specific action)
  def test_delete
    opts = { :controller => 'auto_admin', :action => 'delete', :model => 'user', :id => '7' }
    assert_routing url_for( opts ), opts
  end
end

