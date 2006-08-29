require 'auto_admin_simple_theme'

module AutoAdmin
def self.config
  yield AutoAdminConfiguration
end
module AutoAdminConfiguration
  DefaultTheme = :django
  def self.theme; Object.const_get("AutoAdmin#{theme_name.to_s.camelize}Theme"); end
  def self.theme_name; @@theme ||= DefaultTheme; end
  def self.theme=(theme_name)
    @@theme = theme_name.to_sym
  end
  def self.form_processor; theme::FormProcessor; end
  def self.form_builder; theme::FormBuilder; end
  def self.table_builder; theme::TableBuilder; end
  def self.view_directory; theme.view_directory; end
  def self.asset_root; theme.asset_root; end
  def self.helpers; theme.respond_to?( :helpers ) ? [theme.helpers].flatten : []; end
  def self.controller_includes; theme.respond_to?( :controller_includes ) ? [theme.controller_includes].flatten : []; end

  def self.set_site_info full_url, site_name, admin_site_title='Site Administration'
    ::AutoAdminHelper.site = ::AutoAdminHelper::Site.new full_url, site_name, admin_site_title
  end
  def self.primary_objects; @@primary_objects ||= []; end
  def self.primary_objects= new_value; @@primary_objects = new_value; end
  def self.controller_super_class; @@controller_super_class ||= ActionController::Base; end
  def self.controller_super_class=(klass); @@controller_super_class = klass; end
  def self.model name
    Object.const_get( name.to_s.camelcase )
  end
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
    def self.defaulted_accessor name, default_value
      class_eval <<EVAL
        def #{name}; @#{name} ||= (respond_to?(:default_#{name}) ? default_#{name} : nil) || #{default_value}; end
        def #{name}= new_value; @#{name} = new_value; end
EVAL
    end
    def self.array_accessor *names
      names.each {|name| defaulted_accessor name, '[]' }
    end
    def self.hash_accessor *names
      names.each {|name| defaulted_accessor name, '{}' }
    end
    array_accessor :columns_for_search, :columns_for_filter
    hash_accessor :labels_for_columns, :custom_filter_defaults
    def filter_defaults
      f = {}
      columns_for_filter.each { |c| f[c.to_s] = '*' }
      custom_filter_defaults.each { |k,v| f[k.to_s] = v.to_s }
      f
    end
    def default_columns_for_list
      columns = content_columns.select {|c| c.type != :binary }.map {|c| c.name}
      #reflect_on_all_associations.select {|a| a.macro == :belongs_to }.each do |assoc|
      #  columns << assoc.name
      #end
      columns
    end
    def sort_by column, reverse=false; @sort_column = column.to_s; @sort_reverse = reverse; end
    def search_by *columns; extend Searchable; @columns_for_search = columns; end
    def filter_by *columns; @columns_for_filter = ensure_columns_are_filterable!(columns); end
    def ensure_columns_are_filterable! columns
      columns.each do |col|
        raise "Unable to filter #{self} on column '#{col}'" unless filter_type( col )
      end
    end
    def default_filter filters; custom_filter_defaults.update filters.stringify_keys; end
    def list_columns(*columns, &proc)
      if block_given? || !columns.empty?
        @list_fieldset = ListFieldset.new(self, columns, proc)
      else
        @list_fieldset || ListFieldset.new(self, default_columns_for_list)
      end
    end
    def column_labels labels; labels_for_columns.update labels.stringify_keys; end
    def column_label column; labels_for_columns[column.to_s] || default_column_label( column.to_s ); end
    def default_column_label column
      label = column.to_s.humanize
      label = "Date #{label.downcase}" if label.gsub!(/ on$| at$/, '')
      label
    end

    def find_column name; name &&= name.to_s.sub(/\?$/, ''); columns.find { |c| name == c.name }; end

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

    def filter_option_sql column_name, option_name
      filter_instance(column_name).sql(option_name)
    end

    def filter_options_for column_name, custom_options, &block
      (@custom_filter_options ||= {})[column_name.to_sym] = AutoAdmin::CustomFilterSet.new( column_name, custom_options, &block )
    end
    def filters
      columns_for_filter.map { |col| filter_instance( col ) }
    end
    def filter_instance column_name
      column_name = column_name.to_sym
      return @custom_filter_options[column_name] if @custom_filter_options && @custom_filter_options.has_key?( column_name )

      klass = case type = filter_type( column_name )
      when :belongs_to: AutoAdmin::AssociationFilterSet
      when :has_one: AutoAdmin::AssociationFilterSet
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

    array_accessor :admin_fieldsets
    def default_admin_fieldsets
      [InputFieldset.new( self, '', default_columns_for_edit )]
    end
    def active_admin_fieldsets
      sets = admin_fieldsets
      sets = default_admin_fieldsets + sets unless sets.find {|s| s.fieldset_type == :input }
      sets
    end
    def default_columns_for_edit
      magic_fields = %w(created_at created_on updated_at updated_on) 
      columns = content_columns.map {|c| c.name} - magic_fields
      reflect_on_all_associations.select {|a| [:belongs_to, :has_and_belongs_to_many].include?(a.macro) }.each do |assoc|
        columns << assoc.name.to_s
      end
      columns
    end
    def admin_fieldset label='', *columns, &proc
      set = InputFieldset.new( self, label, columns.map {|c| c.to_s }, proc )
      (@admin_fieldsets ||= []) << set
    end
    def admin_child_table label, collection, options={}, &proc
      (@admin_fieldsets ||= []) << TableFieldset.new( self, label, collection, proc, options )
    end
    def admin_child_form collection, options={}, &proc
      (@admin_fieldsets ||= []) << ChildInputFieldset.new( self, collection, proc, options )
    end

    def object_group new_group=nil
      @object_group = new_group if new_group
      @object_group || ''
    end

    class ListFieldset
      attr_accessor :object, :fields, :options, :proc
      def initialize object, fields=[], proc=nil
        @options = fields.last.is_a?(Hash) ? fields.pop : {}
        @object, @fields, @proc = object, fields, proc
      end
      def build builder
        builder.fieldset( :table ) do
          fields.each {|f| builder.static_text f } if fields
          proc.call( builder ) if proc
        end
      end
    end
    class InputFieldset
      attr_accessor :object, :name, :fields, :options, :proc
      def initialize object, name, fields=[], proc=nil
        @options = fields.last.is_a?(Hash) ? fields.pop : {}
        @object, @name, @fields, @proc = object, name, fields, proc
      end
      def build builder
        builder.fieldset( :fields, name != '' ? name : nil ) do
          fields.each {|f| builder.auto_field f } if fields
          proc.call( builder ) if proc
        end
      end
      def fieldset_type; :input; end
    end
    class ChildInputFieldset
      attr_accessor :object, :field, :proc, :options
      DEFAULT_CHILD_OPTIONS = { :read_only => true }.freeze
      def initialize object, field, proc, options
        @object, @field, @proc, @options = object, field, proc, DEFAULT_CHILD_OPTIONS.merge(options)
      end
      def build_object(builder, obj, idx, caption)
        builder.inner_fields_for( field.to_s + '_' + idx, obj ) do |inner|
          inner.fieldset( :fields, caption ) do
            yield inner if block_given?
            proc.call( inner ) if proc
          end
        end
      end
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
            build_object(builder, children.build, idx,
              "#{row.class.name.underscore.humanize.downcase} ##{n}")
          end
        end
      end
      def fieldset_type; :child_input; end
      def blank_records; options[:read_only] ? 0 : options[:blank_records] || 3; end
    end
    class TableFieldset < ChildInputFieldset
      attr_accessor :name
      def initialize object, name, field, proc, options
        @name = name
        super object, field, proc, options
      end
      def fieldset_type; :tabular; end

      def build_object(builder, obj, idx, caption)
        builder.with_object(obj) do
          builder.fieldset( :fields, caption ) do
            yield builder if block_given?
            proc.call( builder ) if proc
          end
        end
      end
      def build builder
        children = builder.object.send( field )
        builder.fieldset( :table, name ) do
          model = object.reflect_on_association( field ).klass
          builder.table_fields_for( field, nil, :model => model ) do |inner|
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

    module Searchable
      def append_search_condition!(query, options={})
        unless query.empty?
          conditions = options[:conditions] || []
          conditions = [conditions] unless conditions.is_a? Array
          new_condition = '(' + columns_for_search.map { |col| "#{col} LIKE ?" }.join( ' OR ' ) + ')'
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


