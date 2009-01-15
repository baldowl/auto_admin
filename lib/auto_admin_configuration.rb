require 'auto_admin_simple_theme'

module AutoAdmin
def self.config
  yield AutoAdminConfiguration
end
module AutoAdminConfiguration
  DefaultTheme = :django

  # Returns the active theme module.
  def self.theme; Object.const_get("AutoAdmin#{theme_name.to_s.camelize}Theme"); end

  # Returns the name of the active theme.
  def self.theme_name; @@theme ||= DefaultTheme; end

  # Change the name of the active theme.
  def self.theme=(theme_name)
    @@theme = theme_name.to_sym
  end

  def self.form_processor; theme::FormProcessor; end
  def self.form_builder; theme::FormBuilder; end
  def self.table_builder; theme::TableBuilder; end

  # The view directory is actually dependent on the active theme.
  def self.view_directory; theme.view_directory; end

  # The public directory is actually dependent on the active theme.
  def self.asset_root; theme.asset_root; end

  # Returns the list of the active theme's helpers.
  def self.helpers; theme.respond_to?( :helpers ) ? [theme.helpers].flatten : []; end

  def self.controller_includes; theme.respond_to?( :controller_includes ) ? [theme.controller_includes].flatten : []; end

  Site = Struct.new(:url, :short_url, :name)

  # Set the basic informations about this site. Use it as:
  #
  #   AutoAdmin.config do |admin|
  #     admin.set_site_info 'http://www.example.com/', 'example.com',
  #       'Administration area for example.com'
  #   end
  def self.set_site_info full_url, site_name, admin_site_title='Site Administration'
    self.site = Site.new(full_url, site_name, admin_site_title)
  end

  # Returns informations set by #set_site_info
  def self.site; @@site ||= raise("AutoAdmin not configured: site info not set"); end

  # Lowlevel way to set informations about this site. Use #set_site_info.
  def self.site= new_value; @@site = new_value; end

  # Returns the list of models managed through the auto_admin interface.
  def self.primary_objects; @@primary_objects ||= []; end

  # Set the list of models available through the auto_admin interface. Use it
  # as:
  #
  #   AutoAdmin.config do |admin|
  #     admin.primary_objects = %w(actor film user)
  #   end
  def self.primary_objects= new_value; @@primary_objects = new_value; end

  def self.admin_model; @@admin_model ||= nil; end

  # Set the application model used to authenticate the users. Use it as:
  #
  #   AutoAdmin.config do |admin|
  #     admin.admin_model = account
  #   end
  #
  # See also #admin_model_id=.
  def self.admin_model=(new_value)
    @@admin_model = new_value.to_s.camelize.constantize
  end

  def self.admin_model_id; @@admin_model_id ||= nil; end

  # Set the string/symbol used to store the admin object's id into the
  # session. Use it as:
  #
  #   AutoAdmin.config do |admin|
  #     admin.admin_model_id = :account_id
  #   end
  #
  # See also #admin_model=.
  def self.admin_model_id=(new_value)
    @@admin_model_id = new_value.to_sym
  end

  # The plugin's controller super class; defaults to ActionController::Base.
  def self.controller_super_class; @@controller_super_class ||= ActionController::Base; end

  # Allows to set another class as plugin's controller super class. Use it
  # as:
  #
  #   AutoAdmin.config do |admin|
  #     admin.controller_super_class = AlternativeController
  #   end
  def self.controller_super_class=(klass); @@controller_super_class = klass; end

  # The string used as prefix in the custom routes; defaults to +admin+.
  def self.url_prefix; @@url_prefix ||= 'admin'; end

  # Set the string used as prefix in the custom routes.
  def self.url_prefix= new_value; @@url_prefix = new_value; end

  # Set the list of formats used by the optional export mechanism. Use it as:
  #
  #   AutoAdmin.config do |admin|
  #     admin.save_as = %w(pdf csv)
  #   end
  #
  # For the availabe formats see the content of save_as directory in the
  # plugin home.
  def self.save_as=(formats); @@save_as_formats = formats; end

  # Returns the list of active export formats.
  def self.save_as; @@save_as_formats ||= []; end

  # Turns a simple string into the model class.
  def self.model name
    Object.const_get( name.to_s.camelcase )
  end

  # Yield the pairs (group, grouped objects) for each existing object group.
  def self.grouped_objects
    objects = primary_objects.uniq.map { |po| model(po) }
    groups = objects.map { |o| o.object_group }.uniq.sort
    groups.each do |group|
      group_objects = objects.find_all { |o| o.object_group == group }.sort_by { |o| o.name }
      yield group, group_objects
    end
  end

  def self.append_features base
    super
    base.extend ClassMethods
  end

  module ClassMethods
    # Allows to define the getter and setter methods for +name+, just like
    # standard +attr_accessor+, but the getter method will return
    # +default_value+ instead of +nil+.
    def self.defaulted_accessor name, default_value
      class_eval <<EVAL
        def #{name}; @#{name} ||= (respond_to?(:default_#{name}) ? default_#{name} : nil) || #{default_value}; end
        def #{name}= new_value; @#{name} = new_value; end
EVAL
    end

    # Gets/sets an alternative "human" name for the administered model.
    def human_name(v=nil); @human_name = v if v; @human_name ||= name.titleize; end

    # Sets a list of accessor methods for arrays
    def self.array_accessor *names
      names.each {|name| defaulted_accessor name, '[]' }
    end

    # Sets a list of accessor methods for arrays
    def self.hash_accessor *names
      names.each {|name| defaulted_accessor name, '{}' }
    end

    array_accessor :columns_for_search, :columns_for_filter
    hash_accessor :labels_for_columns, :custom_filter_defaults

    # Sets the "starting" value for the already defined filters. Used
    # internally, not for public consumption.
    def filter_defaults
      f = {}
      columns_for_filter.each { |c| f[c.to_s] = '*' }
      custom_filter_defaults.each { |k,v| f[k.to_s] = v.to_s }
      f
    end

    # Sets the listable column list for the administered object. Used
    # internally, not for public consumption.
    def default_columns_for_list
      columns = content_columns.select {|c| c.type != :binary }.map {|c| c.name}
      #reflect_on_all_associations.select {|a| a.macro == :belongs_to }.each do |assoc|
      #  columns << assoc.name
      #end
      columns
    end

    # Instructs the list view to meta-refresh this often
    def refresh_time time=nil; if defined?(@refresh_time) ; then @refresh_time else @refresh_time = time ; end ; end

    # Instructs the list view to sort on the specified column by default.
    def sort_by column, reverse=false; @sort_column = column.to_s; @sort_reverse = reverse; end

    # Adds rudimentary text searching across the named columns. Note that this
    # defines a <tt>search(many, query, options={})</tt> wrapper around
    # model's <tt>find(many, options)</tt>
    def search_by *columns; extend Searchable; @columns_for_search = columns; end

    # Allows filtering of the list screen by the named columns; filtering
    # currently works for: custom, boolean, date, belongs_to, has_one, and
    # string. Note that the last three will do rather nasty and sub-optimal
    # queries to determine the filter options.
    def filter_by *columns; @columns_for_filter = ensure_columns_are_filterable!(columns); end

    # Used internally to check the filtering configuration, not for public
    # consumption.
    def ensure_columns_are_filterable! columns
      columns.each do |col|
        raise "Unable to filter #{self} on column '#{col}'" unless filter_type( col )
      end
    end

    # Takes a hash of (column, value) pairs, to default a filter to something
    # other than 'All'.
    def default_filter filters; custom_filter_defaults.update filters.stringify_keys; end

    # Sets the list of columns shown on the list screen. Takes either a
    # simple list of column names, or a Field Definition Block.
    def list_columns(*columns, &proc)
      if block_given? || !columns.empty?
        @list_fieldset = ListFieldset.new(self, columns, proc)
      else
        @list_fieldset || ListFieldset.new(self, default_columns_for_list)
      end
    end

    # Sets custom labels for the administered model's columns. Takes an hash
    # like
    #
    #   {:column1 => 'column label', :column2 => 'column label'}
    #
    # Use either symbols or strings for the keys.
    def column_labels labels; labels_for_columns.update labels.stringify_keys; end

    # Returns the column label.
    def column_label column; labels_for_columns[column.to_s] || default_column_label( column.to_s ); end

    # Returns the default column label, derived from the column's name.
    def default_column_label column
      label = column.to_s.humanize
      label = "Date #{label.downcase}" if label.gsub!(/ on$| at$/, '')
      label
    end

    # Given a string representing a column's name, returns the corresponding
    # column object.
    def find_column name; name &&= name.to_s.sub(/\?$/, ''); columns.find { |c| name == c.name }; end

    # Builds up the condition array used by +find+ to retrive the selected
    # records.
    def filter_conditions filter_hash
      statement_parts = []
      parameters = []
      merged_filters = filter_defaults.stringify_keys.merge((filter_hash || {}).stringify_keys)
      filters.each do |filter|
        option_sql = filter.sql( merged_filters[filter.name] )
        unless option_sql.empty?
          statement_parts << option_sql.shift
          parameters.push *option_sql
        end
      end
      [ statement_parts.join( ' AND '), *parameters ] unless statement_parts.empty?
    end

    # Given a column name and a potential value, returns the couple
    #
    #   ["sql fragment with placeholder", value]
    def filter_option_sql column_name, option_name
      filter_instance(column_name).sql(option_name)
    end

    # Specifies a fixed set of choices to be offered as filter options instead
    # of automatically working it out. +custom_options+ musth be a (value,
    # label) hash. The optional block will be given each value in turn, and
    # should return an SQL condition fragment.
    def filter_options_for column_name, custom_options, &block
      (@custom_filter_options ||= {})[column_name.to_sym] = AutoAdmin::CustomFilterSet.new( self, reflect_on_association( column_name ) || find_column( column_name ), custom_options, &block )
    end

    def dynamic_filter_options_for column_name, &block
      filter_options_for( column_name, block )
    end

    # Returns an array of filter objects for the adminstered model.
    def filters
      columns_for_filter.map { |col| filter_instance( col ) }
    end

    # Returns an object representing the filter (custom or not) for the given
    # column.
    def filter_instance column_name
      column_name = column_name.to_sym
      return @custom_filter_options[column_name] if @custom_filter_options && @custom_filter_options.has_key?( column_name )

      klass = case type = filter_type( column_name )
      when :belongs_to: AutoAdmin::AssociationFilterSet
      when :has_one: AutoAdmin::AssociationFilterSet
      when :has_many: AutoAdmin::MultiAssociationFilterSet
      when :has_and_belongs_to_many: AutoAdmin::MultiAssociationFilterSet
      when :datetime: AutoAdmin::DateFilterSet
      else
        const = type.to_s.camelcase + 'FilterSet'
        if AutoAdmin.const_defined?( const )
          AutoAdmin.const_get( const )
        else
          AutoAdmin::EmptyFilterSet
        end
      end

      klass.new( self, reflect_on_association( column_name ) || find_column( column_name ) ) {|col| find_column(col) }
    end

    # Returns the type of the potential filter to use on +column_name+.
    def filter_type column_name
      column_name = column_name.to_sym
      return :custom if @custom_filter_options && @custom_filter_options.has_key?( column_name )

      column = find_column( column_name )
      assoc = reflect_on_association( column_name )
      return ( assoc && assoc.macro ) || ( column && column.type )
    end

    def searchable?; respond_to? :append_search_condition!; end
    def sortable_by? column; find_column column; end
    def default_sort_info; find_column( 'name' ) && { :column => 'name', :reverse => false }; end
    def sort_column; defined?( @sort_column ) ? @sort_column : (default_sort_info[:column] rescue nil); end
    def sort_reverse; defined?( @sort_column ) ? @sort_reverse : (default_sort_info[:reverse] rescue nil); end

    # Gets/sets the per-page item number used by the pagination mechanism in
    # the list screens.
    def paginate_every(n=nil); @paginate = n if n; @paginate || 20; end

    array_accessor :admin_fieldsets
    def default_admin_fieldsets
      [InputFieldset.new( self, '', default_columns_for_edit )]
    end
    def active_admin_fieldsets
      sets = admin_fieldsets
      sets = default_admin_fieldsets + sets unless sets.find {|s| s.fieldset_type == :input }
      sets
    end

    # Returns the list of columns to show by default on the edit screen, i.e.
    # everything but the ActiveRecord's magic fields.
    def default_columns_for_edit
      magic_fields = %w(created_at created_on updated_at updated_on) + [locking_column, inheritance_column]
      columns = content_columns.map {|c| c.name} - magic_fields
      reflect_on_all_associations.select {|a| [:belongs_to, :has_and_belongs_to_many].include?(a.macro) }.each do |assoc|
        columns << assoc.name.to_s
      end
      columns
    end

    # Defines a fieldset for edit views. Takes either a simple list of column
    # names, or a Field Definition Block. For simple use, you can just give it
    # a list of columns, which will be rendered using auto_field.
    #
    #   admin_fieldset :first_name, :last_name, :active, :store
    #
    # or
    #
    #   admin_fieldset do |b|
    #     b.text_field :first_name
    #     b.text_field :last_name
    #     b.auto_field :active
    #     b.select :store
    #   end
    def admin_fieldset label='', *columns, &proc
      set = InputFieldset.new( self, label, columns.map {|c| c.to_s }, proc )
      (@admin_fieldsets ||= []) << set
    end

    # Defines a fieldset for edit views, to show a table of items from a child
    # collection. It uses a Field Definition Block to declare what columns
    # should be shown. Generally, you'd want to use the static_text helper, I
    # suspect. *WARNING*: This has no tests, and I'm almost certain it will
    # break horribly if you try to use anything other than static_text.
    def admin_child_table label, collection, options={}, &proc
      (@admin_fieldsets ||= []) << TableFieldset.new( self, label, collection, proc, options )
    end

    # Defines a "fieldset" for edit views, to show *several* fieldsets, each
    # containing one object from a child collection. It uses a Field
    # Definition Block to declare what columns should be shown. I don't think
    # it'd be wise to use this on a large collection, but it's your
    # application. :) *WARNING*: This also has no tests, and I believe it will
    # break horribly if you try to use it at all.
    def admin_child_form collection, options={}, &proc
      (@admin_fieldsets ||= []) << ChildInputFieldset.new( self, collection, proc, options )
    end

    # Declares which 'object group' this object belongs to, for use in the
    # interface. Currently, this is used to group together related objects on
    # the index page.
    def object_group new_group=nil
      @object_group = new_group if new_group
      @object_group || ''
    end

    # Represents the list of fields to show on the list view.
    class ListFieldset
      attr_accessor :object, :fields, :options, :proc
      def initialize object, fields=[], proc=nil
        @options = fields.last.is_a?(Hash) ? fields.pop : {}
        @object, @fields, @proc = object, fields, proc
      end

      # Assembles the field list using a custom form +builder+.
      def build builder
        builder.fieldset( :table ) do
          fields.each {|f| builder.static_text f } if fields
          proc.call( builder ) if proc
        end
      end
    end

    # Represents the collection of fields to show on the edit view.
    class InputFieldset
      attr_accessor :object, :name, :fields, :options, :proc
      def initialize object, name, fields=[], proc=nil
        @options = fields.last.is_a?(Hash) ? fields.pop : {}
        @object, @name, @fields, @proc = object, name, fields, proc
      end

      # Assembles the form's field using a custom form +builder+.
      def build builder
        builder.fieldset( :fields, name != '' ? name : nil ) do
          fields.each {|f| builder.auto_field f } if fields
          proc.call( builder ) if proc
        end
      end

      # The type of this fieldset, used to distinguish it from the other
      # custom fieldset.
      def fieldset_type; :input; end
    end

    # Represents the collection of fieldsets to show on the edit view in the
    # child form. It defaults to build a read-only collection.
    #
    # Recognized options:
    # * <tt>:read_only</tt> (defaults to +true+): control whether the child
    #   records can be modified and/or added to;
    # * <tt>:blank_records</tt> (defaults to 3): control how many new/blank
    #   record to show if the child form is not read-only.
    class ChildInputFieldset
      attr_accessor :object, :field, :proc, :options
      DEFAULT_CHILD_OPTIONS = { :read_only => true }.freeze
      def initialize object, field, proc, options
        @object, @field, @proc, @options = object, field, proc, DEFAULT_CHILD_OPTIONS.merge(options)
      end

      # Assembles the single child's fieldset.
      def build_object(builder, obj, idx, caption)
        builder.inner_fields_for( field.to_s + '_' + idx, obj ) do |inner|
          inner.fieldset( :fields, caption ) do
            yield inner if block_given?
            proc.call( inner ) if proc
          end
        end
      end

      # Assembles the child form's fieldsets using a custom form +builder+.
      def build builder, children=nil
        children ||= builder.object.send( field )
        idx = -1
        children.each_with_index do |row, idx|
          build_object(builder, row, idx, row.to_label) do |inner|
            inner.hidden_field :id
          end
        end
        if children.respond_to? :build
          1.upto blank_records do |n|
            idx += 1
            o = children.build
            children.delete o
            build_object(builder, o, idx,
              "#{o.class.human_name} ##{n}")
          end
        end
      end

      # The type of this fieldset, used to distinguish it from the other
      # custom fieldset.
      def fieldset_type; :child_input; end

      # Returns the number of new, blank records to show in the fieldset if
      # it's not <tt>:read_only</tt>. Customizable via
      # <tt>:blank_records</tt>.
      def blank_records; options[:read_only] ? 0 : options[:blank_records] || 3; end
    end

    # Represents the collection of fieldsets to show on the edit view in the
    # child table.
    class TableFieldset < ChildInputFieldset
      attr_accessor :name
      def initialize object, name, field, proc, options
        @name = name
        super object, field, proc, options
      end

      # The type of this fieldset, used to distinguish it from the other
      # custom fieldset.
      def fieldset_type; :tabular; end

      # Assembles the single child's fieldset.
      def build_object(builder, obj, idx, caption)
        name = field.to_s.dup
        name << '[' << idx.to_s << ']' if idx
        builder.with_object(obj, name) do
          builder.fieldset( :fields, caption ) do
            yield builder if block_given?
            proc.call( builder ) if proc
          end
        end
      end

      # Assembles the child form's fieldsets using a custom form +builder+.
      def build builder
        children = builder.object.send( field )
        builder.fieldset( :table, name ) do
          model = object.reflect_on_association( field ).klass
          opts = options.merge( :model => model )
          builder.table_fields_for( field, nil, opts ) do |inner|
            inner.outer do
              inner.prologue do
                build_object(inner, nil, nil, nil)
              end
              super inner, children
              inner.epilogue do
              end
            end
          end
        end
      end
    end

    # The crude search mechanism.
    module Searchable
      def append_search_condition!(query, options={})
        unless query.empty?
          conditions = options[:conditions] || []
          conditions = [conditions] unless conditions.is_a? Array
          new_condition = '(' + columns_for_search.map { |col| "lower(#{col}) LIKE lower(?)" }.join( ' OR ' ) + ')'
          if conditions.size > 0
            conditions[0] = "(#{conditions[0]}) AND (#{new_condition})"
          else
            conditions[0] = new_condition
          end
          conditions.push *( [ "%#{query}%" ] * columns_for_search.size )
          options[:conditions] = conditions
        end
        options
      end
      def search many, query, options={}
        options = options.dup
        append_search_condition! query, options
        find many, options
      end
    end
  end

  ::ActiveRecord::Base.send :include, self
end
end
