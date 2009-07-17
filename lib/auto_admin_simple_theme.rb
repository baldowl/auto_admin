module AutoAdmin
  module ThemeHelpers
    def view_directory
      directory 'views'
    end
    def asset_root
      directory 'public'
    end
    def controller_includes *includes, &proc
      @controller_includes ||= []
      includes.each do |mod|
        @controller_includes << mod
      end
      if block_given?
        @controller_includes << Module.new(&proc)
      end
      @controller_includes
    end
    def helpers
      @helpers || []
    end
    def helper *helpers, &proc
      @helpers ||= []
      helpers.each do |helper|
        @helpers << helper
      end
      if block_given?
        @helpers << Module.new(&proc)
      end
    end
  end

  module TableBuilder
    def outer;                         %(<table>);              end
    def prologue;     @header = true;  %(<thead><tr>);          end
    def end_prologue; @header = false; %(</tr></thead><tbody>); end
    def epilogue;                      %(</tbody>);             end
    def end_outer;                     %(</table>);             end

    def fieldset(style, title=nil)
      @header ? '' : %(<tr class="row#{(@alt = !@alt) ? 1 : 2}">)
    end
    def end_fieldset
      @header ? '' : %(</tr>)
    end

    def table_header(field_type, field_name, options)
      content_tag('th', yield, options[:attributes] || {})
    end
    def table_cell(field_type, field_name, options)
      content_tag('td', yield, options[:attributes] || {})
    end

    def wrap_field(field_type, field_name, options, &block)
      if @header
        table_header( field_type, field_name, options ) do ||
          label_text( field_name, options )
        end
      else
        table_cell( field_type, field_name, options, &block )
      end
    end

    #def self.append_features base
    #  # I don't think I actually need this cleverness...
    #  instance_methods(false).each do |meth|
    #    base.class_eval "alias :shadow_#{meth} :#{meth}", __FILE__, __LINE__
    #  end
    #  super
    #end
  end

  def self.TableBuilder(form_builder)
    klass = Class.new(form_builder)
    klass.send :include, TableBuilder
    klass
  end

  module AutoFieldTypeSelector
    # TODO: We need to provide a facility for registration of automatic
    # field handlers -- esp. for composed_of, but maybe also for some
    # belongs_to (in both cases, based on the class, presumably)
    def auto_field(field, read_only = false)
      field_type = macro_type(field)

      if read_only
        static_text field
      else
        case field_type
        when :belongs_to #, :has_one
          select field
#        when :has_and_belongs_to_many #, :has_many
#          select field, :multiple => true, :size => 7
        when :has_and_belongs_to_many, :has_many, :has_one
          # Until I work out a better strategy, we skip these.
        when :text
          text_area field
        when :string
          text_field field
        when :boolean
          radio_group field
        when :date
          date_select field
        when :datetime
          datetime_select field
        else
          # Don't know how to handle this column type, so we'll just use a
          # standard text field, but we'll add a (completely non-standard)
          # HTML attribute of 'unknown', so that looking at the source
          # will help to reveal what's going on.
          text_field field, :unknown => field_type
        end
      end
    end

  end
  module PrivateFormHelpers
    private
    DEFAULT_OPTIONS = { :sort_key => :sort, :link => 1 }.freeze
    def option(opt_name)
      (@options && @options.include?( opt_name )) ? @options[opt_name] : DEFAULT_OPTIONS[opt_name]
    end
    def model
      klass = @object ? @object.class : option(:model)
      raise ArgumentError, "Unable to locate model" unless klass
      klass
    end
    def model_name
      model.name.underscore
    end

    def find_choices(field, options)
      column = model.find_column( field )
      assoc = model.reflect_on_association( field.to_sym )
      macro = ( assoc && assoc.macro ) || ( column && column.type )

      # If we were given a choice set, handle it
      choices = options.delete(:choices)
      if macro == :boolean && choices.is_a?( Array ) && 
        choices.size == 2 && choices.all? {|c| c.is_a? String }

        # Special case this one for API simplicity
        return [[choices.first, true], [choices.last, false]]
      end
      return choices.to_a if Hash === choices
      return choices if choices.respond_to? :each
      raise "Expected Array or Hash as :choices" unless choices.nil?

      # We haven't been explicitely told what to do, so we guess the
      # applicable choices
      case macro
      when :boolean
        [['True', true], ['False', false]]
      when :belongs_to, :has_and_belongs_to_many, :has_many, :has_one
        assoc.klass.find(:all).map {|o| [o.to_label, o.id] }
      else
        # FIXME: This situation is hit for has_enumerated
        #raise "Don't know how to find choices for #{field} (#{macro.inspect})"
        []
      end
    end
    def get_option(options, option_name, object, default_value)
      result = default_value
      if options[option_name]
        result = options[option_name]
        result = result.call( object ) if result.respond_to? :call
      end
      result
    end
    def common_option_translations!(options)
      classes = (options[:class] || '').split
      classes << 'required' if options.delete( :required )
      options[:class] = classes.join(' ')

      options[:size] ||= 7 if options[:multiple]
    end
    def get_column_from_field(field)
      assoc = model.reflect_on_association( field.to_sym )
      assoc ? ([:has_many, :has_and_belongs_to_many].include?(assoc.macro) ? "#{field.to_s.singularize}_ids" : assoc.primary_key_name) : field
    end

    def macro_type(column_name)
      column = model.find_column( column_name )
      assoc = model.reflect_on_association( column_name.to_sym )
      return ( assoc && assoc.macro ) || ( column && column.type )
    end
  end
  class BaseFormBuilder < ActionView::Helpers::FormBuilder
    include AutoFieldTypeSelector
    include PrivateFormHelpers

    def none_string(options)
      '(none)'
    end
    def helpers
      @template
    end
    def h(string)
      helpers.send :h, string
    end
    def link_to(*a)
      helpers.send :link_to, *a
    end

    def field_invalid?(field)
      column = get_column_from_field(field)
      @object.errors.invalid? column
    end
    def field_errors(field)
      column = get_column_from_field(field)
      [@object.errors[column]].flatten
    end
    private :none_string, :helpers, :h, :link_to, :field_invalid?,
      :field_errors

    def field_value(field)
      @object.send( get_column_from_field( field ) ) unless @object.nil?
    end
    private :field_value

    def object_helper(helper_name, field, options, *extra)
      @template.send(helper_name, @object_name, field, options.merge( :object => @object ), *extra)
    end
    private :object_helper

    def inner_fields_for(inner_object_name, inner_object)
      @template.fields_for( "#{@object_name}_#{inner_object_name}", inner_object, @template, @options ) do |i|
        yield i
      end
    end
    def table_fields_for(inner_object_name, inner_object, extra_options={}, &proc)
      options = @options.dup
      options[:inner_builder] = options.delete(:table_builder)
      options[:binding] ||= @proc.binding
      options.update extra_options
      @template.fields_for( "#{@object_name}_#{inner_object_name}", inner_object, @template, options ) do |i|
        yield i
      end
    end
    def with_object(object, object_name=@object_name)
      previous_object, @object = @object, object
      previous_object_name, @object_name = @object_name, object_name
      yield
      @object, @object_name = previous_object, previous_object_name
      @object
    end

    def hidden_field(field, options = {})
      common_option_translations! options
      super
    end
    def date_select(field, options = {})
      options[:include_blank] = true
      common_option_translations! options
      super(field, options)
    end
    def datetime_select(field, options = {})
      options[:include_blank] = true
      common_option_translations! options
      super(field, options)
    end

    # To use this helper there must be a separate controller which provides
    # the completion data. Let's say we have the Item model, with a :name
    # attribute for which we want autocompletion, and that there's the
    # ItemsControler; we should add
    #
    #   auto_complete_for :item, :name
    #
    # to the controller. Then, in the Item model we should add
    #
    #   admin_fieldset do |b|
    #     b.text_field_with_auto_complete :name,
    #       :completion => {:url => {:controller => 'items',
    #         :action => 'auto_complete_for_item_name'}}
    #     # ...
    #   end
    #
    # If our design is REST-like, we must tweak the resources' definitions or
    # add a specific route for this action to work:
    #
    #  map.resources :items,
    #    :collection => {:auto_complete_for_item_name => :post}
    def text_field_with_auto_complete(field, options = {})
      common_option_translations! options
      completion_options = options.delete(:completion) || {}
      raise "AutoAdmin text_field_with_auto_complete requires explicit :completion => { :url => .. }" unless completion_options.key? :url
      object_helper :text_field_with_auto_complete, field, options, completion_options
    end
    def text_field(field, options = {})
      common_option_translations! options
      super
    end
    def text_area(field, options = {})
      common_option_translations! options
      super
    end
    def html_area(field, options = {})
      common_option_translations! options
    end
    def select(field, options = {}, html_options = {})
      common_option_translations! options
      dropdown_options = find_choices(field, options)
      column = get_column_from_field(field)
      options[:selected] = field_value( field )

      %(class).map {|k| k.to_sym }.each do |k|
        html_options[k] = options.delete( k ) if options.include?( k )
      end
      super( field, dropdown_options, options, html_options )
    end
    def multiselect(field, options = {}, html_options = {})
      common_option_translations! options
      dropdown_options = find_choices(field, options)
      column = get_column_from_field(field)
      html_defaults = { :size => 8, :multiple => true,
        :name => "#{@object_name}[#{column}][]",
        :id => "#{@object_name}_#{column}" }

      helpers.content_tag('select', helpers.options_for_select( dropdown_options, @object && @object.send(column) ), html_defaults.merge( html_options ) )
    end
    def radio_group(field, options = {})
      common_option_translations! options
      choices = find_choices(field, options)
      choices = choices.to_a if choices.is_a? Hash
      value = field_value( field )
      combine_radio_buttons(choices.map do |choice|
        opts = options.dup
        # FIXME: This should be setting :checked to true or false,
        # which'll work on edge rails, but not 1.1.
        opts.update( :checked => 'checked' ) if value.to_s == choice.last.to_s
        radio_button( field, choice.last, opts ) + " " + h( choice.first )
      end)
    end
    def check_box(field, options = {}, checked_value = '1', unchecked_value = '0')
      common_option_translations! options
      super
    end
    def hyperlink(field, options = {})
      value = @object.send( field )
      return none_string( options ) if value.nil?

      caption = get_option( options, :link_text, value, h( value.to_label ) )
      url = get_option( options, :url, value, 
        { :controller => 'auto_admin', :action => 'edit', :model => value.class.name.underscore, :id => value.id } )

      link_to( caption, url )
    end
    def file_field(field, options = {})
      common_option_translations! options
      super
    end
    def image_field(field, options = {})
    end
    def secure_password(field, options = {})
      common_option_translations! options
      self.password_field field, options
    end

    def static_image(field, options = {})
      value = @object.send field
      return none_string(options) if value.nil?
      controller = options.delete(:controller) || 'auto_admin'
      action = options.delete(:action) || 'edit'
      options[:src] ||= helpers.send(:url_for, :controller => controller,
        :action => action, :id => @object.send(:id))
      if options[:size]
        options[:width], options[:height] = options.delete(:size).split("x")
      end
      options[:alt] ||= @object.send(:to_label)
      if block_given?
        v = yield @object
        options.merge!(v) if v.kind_of? Hash
      end
      helpers.send(:tag, "img", options)
    end
    def static_file(field, options = {})
      hyperlink field, options
    end
    def static_text(field, options = {})
      v = @object.send(field)
      h( v.nil? ? v : v.to_label )
    end
    def calculated_text(options = {}) # :yields: object
      v = yield @object
      h( v.nil? ? v : v.to_label )
    end
    def static_html(field, options = {})
      @object.send field
    end
    def calculated_html(options = {}) # :yields: object
      yield @object
    end
    def html(content = nil, options = {}) # :yields: object
      raise ArgumentError, "Missing block or field name" unless content || block_given?
      block_given? ? yield( @object ) : content
    end

    def self.calculated_helpers
      BaseFormBuilder.public_instance_methods(false).select {|m| m =~ /^calculated_/ }
    end
    def self.field_helpers
      methods = BaseFormBuilder.public_instance_methods(false) - calculated_helpers - %w(html auto_field with_object inner_fields_for table_fields_for)
      ends = methods.select {|m| m =~ /^end_/ }
      begins = ends.map {|m| m.sub /^end_/, '' }
      methods - begins - ends
    end

    def label_text(field_name, options)
      options[:label] || model.column_label( field_name )
    end
    private :label_text

    def combine_radio_buttons(items)
      items.join ' '
    end
    private :combine_radio_buttons

    def outer;        %(); end
    def prologue;     %(); end
    def end_prologue; %(); end
    def epilogue;     %(); end
    def end_epilogue; %(); end
    def end_outer;    %(); end
  end
end

module AutoAdminSimpleTheme
  extend AutoAdmin::ThemeHelpers
  def self.directory(*subdirs)
    raise "Can't use 'simple' theme; it's just an abstract base for other themes."
  end

  # This FormProcessor defines all the standard field helpers; they're
  # just calls to common_field_translations! (which calls
  # translate_association_to_column!), because everything else about the
  # standard field helpers is handled by the standard save action.
  class FormProcessor
    include AutoAdmin::AutoFieldTypeSelector
    include AutoAdmin::PrivateFormHelpers

    def table_fields_for(inner_object_name, inner_object, extra_options={}, &proc)
      options = @options.dup
      options.update extra_options
      if table_params = @controller.params[inner_object_name]
        table_params.each do |row_number, row_params|
          if row_params
            yield self.class.new( inner_object, inner_object_name, extra_options[:model], @controller, row_params, options )
          end
        end
      end
    end
    def with_object(object, object_name=@object_name)
      previous_object, @object = @object, object
      previous_object_name, @object_name = @object_name, object_name
      yield
      @object, @object_name = previous_object, previous_object_name
      @object
    end

    attr_accessor :object, :object_name, :model, :controller, :params, :options
    def initialize(object, object_name, model, controller, params, options={})
      @object, @object_name, @model, @controller, @params, @options =
        object, object_name, model, controller, params, options
    end

    # Calculated helpers are always read-only, so they needn't do
    # anything in a FormProcessor.
    AutoAdmin::BaseFormBuilder.calculated_helpers.each do |helper|
      class_eval <<-end_src, __FILE__, __LINE__
        def #{helper}(options={}); end
      end_src
    end

    AutoAdmin::BaseFormBuilder.field_helpers.each do |helper|
      class_eval <<-end_src, __FILE__, __LINE__
        def #{helper}(field, options={}, *args, &proc)
          common_field_translations! field
        end
      end_src
    end
    def nullable(field_type, field, options={})
      check_for_nullable_field! field
      common_field_translations! field
    end

    %w(outer prologue epilogue).each do |helper|
      class_eval <<-end_src, __FILE__, __LINE__
        def #{helper}; yield if block_given?; end
        def end_#{helper}; end
      end_src
    end
    def fieldset(style, title=nil); yield if block_given?; end
    def end_fieldset; end


    def common_field_translations!(field_name)
      return unless params.include? field_name
      translate_association_to_column! field_name
    end
    def check_for_nullable_field!(field_name)
      params[field_name] = nil if params.delete( "#{field_name}_NULL" ) == 'NULL'
    end
    def translate_association_to_column!(field_name)
      column = get_column_from_field( field_name )
      return if column.to_s == field_name.to_s
      params[column] = params.delete( field_name )
    end
  end

  class FormBuilder < AutoAdmin::BaseFormBuilder
    def wrap_field(field_type, field_name, options)
      label = label_text( field_name, options )
      klass = options[:required] ? 'required' : ''
      %(<label class="#{klass}" for="#{@object_name}_#{field_name}">#{h label}:</label> #{yield}<br />)
    end

    def fieldset_class(style)
      case style
      when :fields then 'fields'
      end
    end
    def fieldset(style, title=nil)
      %(<fieldset class="#{fieldset_class style}">) +
        (title ? %(<h2>#{h title}</h2>) : '')
    end
    def end_fieldset
      %(</fieldset>)
    end

    def nullable(field_type, field_name, options={})
      wrap_field field_type, field_name, options do |*a|
        null_label = options.delete(:null_label) || 'None'
        standard_field = send("#{field_type}_without_theme", field_name, options)
        is_null = field_value(field_name).nil?
        <<-foo
        <input type="radio" name="#{@object_name}[#{field_name}_NULL]" value="NULL" #{'checked="checked" ' if is_null}/> #{null_label}<br />
        <input type="radio" name="#{@object_name}[#{field_name}_NULL]" value="" #{'checked="checked" ' unless is_null}/> #{standard_field}
        foo
      end
    end

    calculated_helpers.each do |helper|
      class_eval <<-end_src, __FILE__, __LINE__
        alias :#{helper}_without_theme :#{helper}
        def #{helper}(options={}, *args, &proc)
          wrap_field #{helper.to_sym.inspect}, nil, options do |*a|
            a.empty? ? #{helper}_without_theme(options, *args, &proc) : #{helper}_without_theme(*a)
          end
        end
      end_src
    end
    (field_helpers - %w(hidden_field)).each do |helper|
      class_eval <<-end_src, __FILE__, __LINE__
        alias :#{helper}_without_theme :#{helper}
        def #{helper}(field, options={}, *args, &proc)
          wrap_field #{helper.to_sym.inspect}, field, options do |*a|
            a.empty? ? #{helper}_without_theme(field, options, *args, &proc) : #{helper}_without_theme(*a)
          end
        end
      end_src
    end
  end
  class TableBuilder < AutoAdmin::TableBuilder(FormBuilder)
  end
end

