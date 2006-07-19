
class AutoAdminController < ActionController::Base
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
    if session[:user]
      if permit_user_to_access_admin( session[:user] )
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

  def index
    @no_crumbs = true
    @history_items = AdminHistory.find( :all, :conditions => ['user_id = ?', user.id], :order => 'created_at DESC', :limit => 10 ) if has_history?
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
      yield if block_given?
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
    options.update( :per_page => (params[:per_page] || 20).to_i, :singular_name => params[:model] )
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
      unless @object.update_attributes( params[params[:model]] ) && @object.valid?
        render :action => 'edit' and return
      end

      # Save child objects
      # FIXME: This is currently quite entirely broken. At least it
      # isn't preventing the main object from being saved, so it should
      # be okay for read-only lists.
      model.admin_fieldsets.each do |set|
        case set.fieldset_type
        when :tabular, :child_input
          children = @object.send( set.field )
          child_class = children.build.class
          child_params = params["#{params[:model]}_#{set.field}"]
          child_params.each do |child_index, child_info|
            next unless Hash === child_info
            o = child_info[:id] ? child_class.find( child_info[:id] ) : children.build
#            child_info.delete :id
            unless o.update_attributes child_info
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
        history = { :user_id => session[:user].id, :object_label => @object.to_label, :model => params[:model], :obj_id => @object.id }
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
    @histories = AdminHistory.find :all, :conditions => ['model = ? AND obj_id = ?', params[:model], params[:id]], :order => 'admin_histories.created_at DESC', :limit => 50, :include => [:user]
  end

  # FIXME: Force use of POST, showing a confirmation page on GET. Isn't
  # there a plugin that does that? I can't find it on the Wiki atm...
  def delete
    object = model.find( params[:id] )
    label = @object.to_label
    hist = AdminHistory.new( :user_id => session[:user].id, :object_label => @object.to_label, :model => params[:model], :obj_id => params[:id], :change => 'delete', :description => 'Record deleted' ) if has_history?
    object.destroy
    flash[:notice] = "The #{human_model.downcase} \"#{object.to_label}\" was deleted successfully."
    hist.save! if hist
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

