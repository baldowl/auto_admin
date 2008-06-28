module AutoAdminHelper
  def model name=nil
    AutoAdmin::AutoAdminConfiguration.model( name || params[:model] )
  end

  # We can't just use const_defined?, because we want to give Rails a
  # chance to auto-load it.
  def has_history?
    AdminHistory rescue nil
  end
  def has_user?
    User rescue nil
  end


  def site
    AutoAdmin::AutoAdminConfiguration.site
  end
  def user
    session[:user_id] ? User.find(session[:user_id]) : nil
  end
  def human_model name=nil, pluralize=false
    s = model(name).human_name
    s = s.pluralize if pluralize && pluralize != 1
    s
  end






  def value_html_for object, field, explicit_none=false, return_klass=false
    value = object.send(field)
    value = value.to_label if value.is_a? ActiveRecord::Base
    column = model.find_column(field)
    assoc = model.reflect_on_association(field)
    klass = assoc ? assoc.klass.name.underscore.to_s : column.type.to_s
    cell_content = case column && column.type
      when :boolean
        value = value ? 'Yes' : 'No'
        image_tag url_for( :escape => false, :action => :asset, :path => "images/auto_admin/icon-#{value.downcase}.gif" ), :alt => value, :title => value
      else
        h value
      end
    if value.nil? || value == ''
      cell_content = explicit_none ? '(none)' : ''
      klass << ' none'
    end
    ret = [ cell_content ]
    ret << klass if return_klass
    return *ret
  end

  def list_page_for_current
    list_page_for params[:model]
  end
  def list_page_for model
    param_hash_to_link_hash( (session[:admin_list_params] || {})[model] || {} ).merge( :action => 'list', :model => model )
  end
  def current_list_page
    param_hash_to_link_hash params
  end
  def current_list_page_as_fields *skip_keys
    link_hash_to_hidden_fields current_list_page, skip_keys + [:controller, :action, :model, :id]
  end
  def similar_list_page options_changed
    param_hash_to_link_hash params.merge( options_changed )
  end
  def similar_list_page_with_filter column, option
    filter_hash = (params[:filter] || {}).dup
    filter_hash[column] = option
    filter_hash.delete column unless option
    similar_list_page :filter => filter_hash
  end
  def link_hash_to_hidden_fields hash, skip_keys=[]
    hash.reject {|k,v| skip_keys.include? k.to_sym }.to_a.map {|pair| hidden_field_tag pair[0], pair[1] }.join( "\n" )
  end
  def param_hash_to_link_hash hash
    hash = hash.dup
    if klass = hash[:model] && model( hash[:model] )
      if hash[:filter]
        f = hash[:filter].dup
        defaults = klass.filter_defaults
        f.delete_if {|k,v| defaults[k] == v }
        hash[:filter] = f
      end
      if hash[:sort].to_s == klass.sort_column.to_s && hash[:sort_reverse] == klass.sort_reverse
        hash.delete :sort
        hash.delete :sort_reverse
      end
    end
    hash.stringify_keys!
    # FIXME: This should handle deeper hash hierarchies, and arrays.
    hash.select {|k,v| v.is_a? Hash }.each do |k,v|
      hash.delete k
      v.each { |k2,v2| hash["#{k}[#{k2}]"] = v2 }
    end
    hash
  end


  def admin_form_for(object_name, object, options={}, &proc)
    opts = { :builder => DeclarativeFormBuilder,
      :inner_builder => AutoAdmin::AutoAdminConfiguration.form_builder,
      :table_builder => AutoAdmin::AutoAdminConfiguration.table_builder,
      :indent => 0, :html => { :multipart => true },
    }.update(options)
    form_for(object_name, object, opts, &proc)
  end
  def admin_table(options={}, &proc)
    opts = { :builder => DeclarativeFormBuilder,
      :inner_builder => AutoAdmin::AutoAdminConfiguration.table_builder,
      :indent => 0,
    }.update(options)
    fields_for(nil, nil, opts, &proc)
  end
end

