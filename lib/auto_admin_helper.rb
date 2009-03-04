module AutoAdminHelper
  # Returns the +name+ model class. Usually the +name+ parameter is
  # unnecessary as the right value is taken from the HTTP request.
  def model name=nil
    AutoAdmin::AutoAdminConfiguration.model( name || params[:model] )
  end

  # We can't just use const_defined?, because we want to give Rails a
  # chance to auto-load it.
  def has_history?
    AdminHistory rescue nil
  end

  # Simple check: no user model, no authentication needed.
  def has_user?
    AutoAdmin::AutoAdminConfiguration.admin_model
  end

  # Returns the Site object set up in the global configuration.
  def site
    AutoAdmin::AutoAdminConfiguration.site
  end

  # Returns the logged in user, if any.
  def user
    session[AutoAdmin::AutoAdminConfiguration.admin_model_id] ? AutoAdmin::AutoAdminConfiguration.admin_model.find(session[AutoAdmin::AutoAdminConfiguration.admin_model_id]) : nil
  end

  # Returns the human name of the given model +name+, optionally pluralizing
  # it.
  def human_model name=nil, pluralize=false
    s = model(name).human_name
    s = s.pluralize if pluralize && pluralize != 1
    s
  end

  # Returns the HTML-escaped value of +object+'s +field+ with or without the
  # value's Ruby class. +explicit_none+ controls how a nil/empty value is
  # represented to the caller: the explicit, hardcoded string '(none)' or an
  # empty string (default behaviour).
  def value_html_for object, field, explicit_none=false, return_klass=false
    value = object.send(field)
    value = value.to_label if value.is_a? ActiveRecord::Base
    column = model.find_column(field)
    assoc = model.reflect_on_association(field)
    klass = assoc ? assoc.klass.name.underscore.to_s : column.type.to_s
    cell_content = case column && column.type
      when :boolean
        value = value ? 'Yes' : 'No'
        image_tag url_for(:action => :asset, :path => %W(images auto_admin icon-#{value.downcase}.gif)), :alt => value, :title => value
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

  # Returns the hash used by +link_to+ to produce the link for the list view
  # of the current model.
  def list_page_for_current
    list_page_for params[:model]
  end

  # Returns the hash used by +link_to+ to produce the link for the list view
  # of the given model.
  def list_page_for model
    param_hash_to_link_hash( (session[:admin_list_params] || {})[model] || {} ).merge( :action => 'list', :model => model )
  end

  # Returns the hash used by +link_to+ to produce the link to the current list
  # view.
  def current_list_page
    param_hash_to_link_hash params
  end

  # Trasforms the current list page "parameters", i.e., the hash used by
  # +link_to+ to produce the URL of the current view, in a number of hidden
  # fields.
  def current_list_page_as_fields *skip_keys
    link_hash_to_hidden_fields current_list_page, skip_keys + [:controller, :action, :model, :id]
  end

  # Returns the hash used by +link_to+ to produce the link to a similar list
  # view, changing just the +options_changed+, which must be a hash.
  def similar_list_page options_changed
    param_hash_to_link_hash params.merge( options_changed )
  end

  # Returns the hash used by +link_to+ to produce the link to a similar list
  # view, just filtered by the given parameters.
  def similar_list_page_with_filter column, option
    filter_hash = (params[:filter] || {}).dup
    filter_hash[column] = option
    filter_hash.delete column unless option
    similar_list_page :filter => filter_hash
  end

  # Returns an array of form hidden fields corresponding to the hash members.
  def link_hash_to_hidden_fields hash, skip_keys=[]
    hash.reject {|k,v| skip_keys.include? k.to_sym }.to_a.map {|pair| hidden_field_tag pair[0], pair[1] }.join( "\n" )
  end

  # Simplifies the hash, purging the unneeded options whose values are just
  # default ones.
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

  # Custom replacement of +form_for+.
  def admin_form_for(object_name, object, options={}, &proc)
    opts = { :builder => DeclarativeFormBuilder,
      :inner_builder => AutoAdmin::AutoAdminConfiguration.form_builder,
      :table_builder => AutoAdmin::AutoAdminConfiguration.table_builder,
      :indent => 0, :html => { :multipart => true },
    }.update(options)
    form_for(object_name, object, opts, &proc)
  end

  # Custom replacement of +fields_for+.
  def admin_table(options={}, &proc)
    opts = { :builder => DeclarativeFormBuilder,
      :inner_builder => AutoAdmin::AutoAdminConfiguration.table_builder,
      :indent => 0,
    }.update(options)
    fields_for(nil, nil, opts, &proc)
  end

  # Returns a link to the specific export action for the +format+ format. The
  # link itself is not customizable.
  def save_as_link_to format
    link_to "Save as #{format.to_s.capitalize}", {:model => params[:model],
      :format => format, :filter => params[:filter], :sort => params[:sort],
      :sort_reverse => params[:sort_reverse], :search => params[:search]}
  end

  # Returns an array of links to the export actions; see #save_as_link_to.
  def save_as_links
    AutoAdmin::AutoAdminConfiguration.save_as.map {|format| save_as_link_to(format)}
  end
end
