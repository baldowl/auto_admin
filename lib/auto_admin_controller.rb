class AutoAdminController < AutoAdmin::AutoAdminConfiguration.controller_super_class
  include AutoAdminHelper
  include AutoAdminSaveAs
  self.view_paths = AutoAdmin::AutoAdminConfiguration.view_directory
  def template_layout
    'layout.html.erb'
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

  before_filter :require_valid_user, :except => [ :login, :asset ]

  # Used as a before filter to check if we have a valid user (i.e., an admin
  # or something like that)
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

  # A valid user must pass these checks.
  def permit_user_to_access_admin user
    user &&
      (!user.respond_to?( :active? ) || user.active?) &&
      (!user.respond_to?( :enabled? ) || user.enabled?) &&
      (!user.respond_to?( :disabled? ) || !user.disabled?) &&
      (!user.respond_to?( :admin? ) || user.admin?)
  end
  private :permit_user_to_access_admin

  def user_history_includes
    AutoAdmin::AutoAdminConfiguration.admin_model.to_s.downcase.to_sym
  end
  def user_history_identity
    { AutoAdmin::AutoAdminConfiguration.admin_model_id => (user && user.id) }
  end

  # Returns the latest +num+ records from the +admin_histories+ table; they're
  # usually displayed in the "index" view by the active theme.
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
      auth_method = [ :authenticate, :login ].detect {|m| AutoAdmin::AutoAdminConfiguration.admin_model.respond_to? m }
      maybe_user_id = AutoAdmin::AutoAdminConfiguration.admin_model.send(auth_method || :find_by_username_and_password, params[:username], params[:password])
      if maybe_user_id
        maybe_user_id = maybe_user_id.id if maybe_user_id.instance_of?(AutoAdmin::AutoAdminConfiguration.admin_model)
        session[AutoAdmin::AutoAdminConfiguration.admin_model_id] = maybe_user_id
        redirect_to :action => 'index'
      end

      flash.now[:warning] = "Invalid username or password"
    end
    @no_crumbs = true
  end
  def logout
    session[AutoAdmin::AutoAdminConfiguration.admin_model_id] = nil
    redirect_to :action => 'index'
  end

  # Ancillary class used to scour the administered model for related class and
  # collect the results
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

  # Handles the basic listing view, creatively building the +find+ options
  # object from the request parameters.
  def list
    params[:filter] ||= {}
    params[:filter] = model.filter_defaults.merge(params[:filter])
    @auto_admin_refresh_time = model.refresh_time
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
    respond_to do |format|
      format.html do
        options.update(:page => params[:page], :per_page => (params[:per_page] || model.paginate_every).to_i)
        @objects = model.paginate(options)
        session[:admin_list_params] ||= {}
        session[:admin_list_params][params[:model]] = params
      end
      save_as_blocks self, format, options
    end
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
      @object.send :attributes=, params[params[:model]], false
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
            
            # update attributes, ignoring protected
            o.send :attributes=, child_info, false
            unless o.save
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
      redirect_to :action => 'edit', :id => @object.id
    elsif params[:_addanother]
      flash[:notice] << "You may add another #{human_model.downcase} below."
      redirect_to :action => 'edit', :id => nil
    else
      redirect_to list_page_for_current
    end
  end
  def edit
    @object = params[:id] ? model.find( params[:id] ) : model.new
  end

  # Returns a bunch (50, actually) of the latest records from the history
  # table used to register admins' actions. To use this feature you need to
  # add a database table like the following one:
  #
  #   create_table :admin_histories do |t|
  #     t.column :obj_id, :integer
  #     t.column :object_label, :string
  #     t.column :model, :string
  #     t.column :user_id, :integer
  #     t.column :change, :string
  #     t.column :description, :string
  #     t.column :created_at, :datetime
  #     t.column :updated_at, :datetime
  #     t.column :lock_version, :integer, :default => 0
  #   end
  #
  # *Nota* *Bene*: the <tt>:user_id</tt> *must* actually be
  # <em><admin model></em>_id, i.e. the same value of
  # AutoAdmin::AutoAdminConfiguration#admin_model_id.
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
    headers['Expires'] = (Time.now + 1.day).utc.to_formatted_s(:rfc822)

    send_file filename, :type => mime_type
  end
end
