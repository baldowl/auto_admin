
class AutoAdminController < AutoAdmin::AutoAdminConfiguration.controller_super_class
  include AutoAdminHelper
  def self.template_root
    AutoAdmin::AutoAdminConfiguration.view_directory
  end
  def template_layout
    './layout'
  end
  # Just the action name, thanks; we use our custom template_root to
  # handle the rest.
  def default_template_name(action_name = self.action_name)
    super.split('/').last
  end
  layout :template_layout

  # TODO: Write out a form containing the entire contents of params
  # (except the bits that go in the URL), with a message of "Please
  # click 'OK' to save your changes to 'Foo'", determined via a case
  # statement over the requested action
  verify :method => :post, :only => %w( save delete )
    #, :redirect_to => { :action => 'confirm_post' }

  helper AutoAdmin::AutoAdminConfiguration.helpers
  AutoAdmin::AutoAdminConfiguration.controller_includes.each do |inc|
    include inc
  end

  #model :user
  before_filter :require_valid_user, :except => [ :login, :asset ]
  def require_valid_user
    return unless has_user?

    valid_user = false
    if user
      if permit_user_to_access_admin( user )
        valid_user = true
      else
        flash[:warning] = 'Not permitted to access administration interface'
      end
    end
    redirect_to :action => 'login', :model => nil unless valid_user
  end
  def permit_user_to_access_admin user
    user &&
      (!user.respond_to?( :active? ) || user.active?) &&
      (!user.respond_to?( :enabled? ) || user.enabled?) &&
      (!user.respond_to?( :disabled? ) || !user.disabled?) &&
      (!user.respond_to?( :admin? ) || user.admin?)
  end
  private :permit_user_to_access_admin

  def user_history_includes
    :user
  end
  def user_history_identity
    { :user_id => (user && user.id) }
  end
  def user_history_items(num=10)
    conditions = []
    condition_values = []
    user_history_identity.each {|k,v| conditions << "#{k} = ?"; condition_values << v }
    AdminHistory.find( :all, 
      :conditions => [conditions.join(' AND '), *condition_values], 
      :order => 'created_at DESC', :limit => num )
  end
  private :user_history_items

  def index
    @no_crumbs = true
    @history_items = user_history_items if has_history?
  end
  def login
    if request.post?
      auth_method = [ :authenticate, :login ].detect {|m| User.respond_to? m }
      if session[:user] = User.send( auth_method || :find_by_username_and_password, params[:username], params[:password] )
        redirect_to :action => 'index'
      end

      flash.now[:warning] = "Invalid username or password"
    end
    @no_crumbs = true
  end
  def logout
    session[:user] = nil
    redirect_to :action => 'index'
  end

  class AssociationCollector
    attr_reader :model, :associations
    def initialize(model)
      @model, @associations = model, []
    end
    def method_missing method, field=nil, options={}
      associations << field if field && model.reflect_on_association( field )
    end
  end
  def collect_associations_for_model
    collector = AssociationCollector.new(model)
    model.list_columns.build collector
    collector.associations
  end
  private :collect_associations_for_model
  def list
    params[:filter] ||= {}
    params[:filter] = model.filter_defaults.merge(params[:filter])
    conditions = model.filter_conditions( params[:filter] )
    unless sort_column = model.find_column( params[:sort] )
      sort_column = model.find_column( params[:sort] = model.sort_column )
      params[:sort_reverse] = model.sort_reverse
    end
    params[:sort_reverse] ||= false
    order = sort_column && "#{model.table_name}.#{sort_column.name} #{params[:sort_reverse] ? 'DESC' : 'ASC'}"
    options = { :conditions => conditions, :order => order }
    options[:include] = collect_associations_for_model
    if params[:search] && model.searchable?
      model.append_search_condition! params[:search], options
    end
    options.update( :per_page => (params[:per_page] || model.paginate_every).to_i, :singular_name => params[:model] )
    @pages, @objects = paginate(params[:model], options)
    session[:admin_list_params] ||= {}
    session[:admin_list_params][params[:model]] = params
  end

  def save
    model.transaction do
      @object = params[:id] ? model.find( params[:id] ) : model.new

      # Use the active theme's FormProcessor to perform any required
      # translations within the parameter hash
      processor = AutoAdmin::AutoAdminConfiguration.form_processor.new( @object, params[:model], model, self, params[params[:model]] )
      model.active_admin_fieldsets.each do |set|
        set.build processor
      end

      # Save attributes on the primary object
      @object.attributes = params[params[:model]]
      unless @object.save
        flash[:warning] = "Failed to update the #{human_model.downcase} \"#{@object.to_label}\". "
        render :action => 'edit' and return
      end

      # Save child objects... seems to work at the moment (for tables,
      # at least)
      model.admin_fieldsets.each do |set|
        case set.fieldset_type
        when :tabular, :child_input
          next if set.options[:read_only]

          is_blank = lambda do |info|
            if set.options[:blank]
              case set.options[:blank]
              when Hash
                set.options[:blank].all? do |k,v|
                  !info.include?(k) ||
                    (Proc === v ? v.call(info[k]) : info[k] === v)
                end
              when Proc
                set.options[:blank].call(info)
              end
            else
              info.values.all? {|v| v.blank? }
            end
          end

          children = @object.send( set.field )
          child_class = children.build.class
          child_params = params[set.field.to_s]
          child_params.each do |child_index, child_info|
            child_info = child_info.dup
            next unless Hash === child_info
            child_id = child_info.delete :id
            if child_info.delete(:delete) == 'DELETE' || is_blank.call(child_info)
              child_class.find( child_id ).destroy if child_id
              next
            end

            o = child_id ? child_class.find( child_id ) : children.build
            unless o.update_attributes child_info
              set_name = 'Child list'
              set_name = set.name if set.respond_to?(:name) && !set.name.blank?
              flash[:warning] = "Failed to #{o.new_record? ? 'add' : 'change'} the #{o.class.name.titleize.downcase} \"#{o.to_label}\" (#{set_name})"
              o.errors.each_full {|s| flash[:warning] << "; " << s }
              flash[:warning] << ". "
              render :action => 'edit' and return
            end
          end if child_params
        end
      end

      if params[:id]
        flash[:notice] = "The #{human_model.downcase} \"#{@object.to_label}\" was changed successfully. "
      else
        flash[:notice] = "The #{human_model.downcase} \"#{@object.to_label}\" was added successfully. "
      end

      if has_history?
        history = { :object_label => @object.to_label, :model => params[:model], :obj_id => @object.id }
        history.update user_history_identity
        if params[:id]
          history.update :change => 'edit', :description => 'Record modified'
        else
          history.update :change => 'add', :description => 'Record created'
        end
        AdminHistory.new( history ).save
      end
    end

    if params[:_continue]
      flash[:notice] << "You may edit it again below."
      redirect_to :action => 'edit', :model => params[:model], :id => @object
    elsif params[:_addanother]
      flash[:notice] << "You may add another #{human_model.downcase} below."
      redirect_to :action => 'edit', :model => params[:model]
    else
      redirect_to list_page_for_current
    end
  end
  def edit
    @object = params[:id] ? model.find( params[:id] ) : model.new
  end

  def history
    @object = params[:id] ? model.find( params[:id] ) : model.new
    @histories = AdminHistory.find :all, :conditions => ['model = ? AND obj_id = ?', params[:model], params[:id]], :order => 'admin_histories.created_at DESC', :limit => 50, :include => [*user_history_includes]
  end

  # FIXME: Force use of POST, showing a confirmation page on GET. Isn't
  # there a plugin that does that? I can't find it on the Wiki atm...
  def delete
    object = model.find( params[:id] )
    label = object.to_label
    if has_history?
      history_hash = { :object_label => label, :model => params[:model], :obj_id => params[:id], :change => 'delete', :description => 'Record deleted' }
      history_hash.update user_history_identity
      history_obj = AdminHistory.new( history_hash )
    end
    object.destroy
    flash[:notice] = "The #{human_model.downcase} \"#{label}\" was deleted successfully."
    history_obj.save! if history_obj
    redirect_to list_page_for_current
  end

  def asset
    mime_type = case params[:path].last
    when /\.css$/; 'text/css'
    when /\.gif$/; 'image/gif'
    when /\.png$/; 'image/png'
    else; 'text/plain'
    end

    roots = [ File.join(File.dirname(File.dirname(__FILE__)), 'public') ]
    roots.unshift AutoAdmin::AutoAdminConfiguration.asset_root

    filename = roots.map {|dir| File.join( dir, params[:path] ) }.detect {|file| File.exist?( file ) }
    raise "Unable to locate asset #{File.join(params[:path]).inspect} in any of #{roots.size} asset roots" unless filename

    # FIXME: Should we do this in develpment mode? "Development"
    # generally means of the application, but what if we're working on a
    # theme?
    @headers['Expires'] = (Time.now + 1.day).utc.to_formatted_s(:rfc822)

    send_file filename, :type => mime_type
  end
end

