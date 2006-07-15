# Copyright (c) 2006 Matthew Draper
# Released under the MIT License.  See the LICENSE file for more details.

class ActionController::Routing::RouteSet
  alias draw_without_admin draw
  def draw_with_admin
    draw_without_admin do |map|
      map.connect 'admin', :controller => 'auto_admin', :action => 'index'
      map.connect 'admin/-/:action/:id', :controller => 'auto_admin', :action => 'index',
        :requirements => { :model => nil }
      map.connect 'admin/asset/*path', :controller => 'auto_admin', :action => 'asset'

      map.connect 'admin/:model/:action', :controller => 'auto_admin', :action => 'list', 
        :requirements => { :action => /[^0-9].*/, :id => nil }
      map.connect 'admin/:model/:id/:action', :controller => 'auto_admin', :action => 'edit', 
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
class ::TrueClass; def to_label; 'Yes'; end; end
class ::FalseClass; def to_label; 'No'; end; end
class ::NilClass; def to_label; '(none)'; end; end

