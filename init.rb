# Copyright (c) 2006 Matthew Draper
# Released under the MIT License.  See the LICENSE file for more details.

require 'auto_admin'

class ActionController::Routing::RouteSet
  alias draw_without_admin draw
  def draw_with_admin
    draw_without_admin do |map|
      prefix = AutoAdmin::AutoAdminConfiguration.url_prefix rescue 'admin'
      map.connect "#{prefix}", :controller => 'auto_admin', :action => 'index'
      map.connect "#{prefix}/asset/*path", :controller => 'auto_admin', :action => 'asset'
      map.connect "#{prefix}/-/:action/:id", :controller => 'auto_admin', :action => 'index',
        :requirements => { :model => nil }

      map.connect "#{prefix}/:model/:action", :controller => 'auto_admin', :action => 'list', 
        :requirements => { :action => /[^0-9].*/, :id => nil }
      map.connect "#{prefix}/:model.:format", :controller => 'auto_admin', :action => 'list'
      map.connect "#{prefix}/:model/:id/:action", :controller => 'auto_admin', :action => 'edit', 
        :requirements => { :id => /\d+/ }
      yield map
    end
  end
  alias draw draw_with_admin
end

class ::Object
  def to_label
    return label if respond_to? :label
    return name if respond_to? :name
    return to_s if respond_to? :to_s
    inspect
  end
end

# We want AssociationProxy to forward #to_label on to its target, but
# because we're adding the above to Object after AssociationProxy
# flushes its instance methods, we have to do it manually.
begin
  ActiveRecord::Associations::AssociationProxy.send :undef_method, :to_label
rescue NameError
  # Nothing to do, really!
end

class ::Array; def to_label; map {|m| m.to_label }.join(', '); end; end
class ::TrueClass; def to_label; 'Yes'; end; end
class ::FalseClass; def to_label; 'No'; end; end
class ::NilClass; def to_label; '(none)'; end; end
