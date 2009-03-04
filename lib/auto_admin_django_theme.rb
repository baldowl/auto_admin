# The Django-based theme module.
module AutoAdminDjangoTheme
  extend AutoAdmin::ThemeHelpers
  def self.directory(*subdirs)
    File.join(File.dirname(File.dirname(__FILE__)), 'themes', 'django', *subdirs)
  end

  helper do
    # Given an AdminHistory instance, it builds the history link which lands
    # the user right into the edit form for the related administered model
    # object.
    def history_link record
      link = "(Unnamed #{human_model(record.model).downcase})"
      link = record.object_label unless record.object_label.blank?
      link = link_to h(link), :model => record.model, :action => 'edit', :id => record.obj_id unless record.change == 'delete'
      link
    end

    # Tweaks the CSS class used for the history items.
    def history_link_class record
      case record.change
        when 'add'; 'addlink'
        when 'delete'; 'deletelink'
        else 'changelink'
      end
    end
  end

  # Nothing special to do to user's data before saving them.
  class FormProcessor < AutoAdminSimpleTheme::FormProcessor
  end

  # Custom FormBuilder used to assemble the administered model editing form
  # sewing together the pieces.
  class FormBuilder < AutoAdminSimpleTheme::FormBuilder
    def fieldset_class(style)
      case style
      when :fields then 'module aligned'
      when :table then 'module'
      end
    end
    def wrap_field(field_type, field_name, options)
      options[:class] = options[:class] ? options[:class].dup : ''
      if field_name
        column = model.find_column( field_name )
        assoc = model.reflect_on_association( field_name.to_sym )
        column_type = ( assoc && assoc.macro ) || ( column && column.type )
      end
      case field_type
      when :text_field
        case column_type
        when :string
          options[:class] << ' vTextField'
          options[:size] ||= 30
          options[:maxlength] ||= column.limit
        when :integer, :decimal
          options[:class] << ' vIntegerField'
          options[:size] ||= 10
        when :text
          options[:class] << ' vTextField'
          options[:size] ||= 50
        end
      when :text_area
        options[:class] << ' vLargeTextField'
      when :check_box
        options[:class] << ' vCheckboxField'
      when :date_select
        options[:class] << ' vDateField'
      when :datetime_select
        options[:class] << ' vTimeField'
      when :select
        options[:class] << ' vSelectMultipleField' if options[:multiple]
      end
#.vFileUploadField { border:none; }
#.vURLField { width:380px; }
#.vLargeTextField, .vXMLLargeTextField { width:480px; }
      options[:class].strip!

      inner = super
      inner << %(<p class="help">#{h options[:caption]}</p>) if options[:caption]

      if field_name && field_invalid?(field_name)
        %(<div class="form-row errors"><ul class="errorlist">) +
          field_errors( field_name ).map {|msg|
            %(<li>This field #{h msg}</li>)
          }.join +
          %(</ul>#{inner}</div>)
      else
        %(<div class="form-row">#{inner}</div>)
      end
    end

    # Used for fields which must not be wrapped in the Django-based theme's
    # divs.
    def static_text_without_theme(field, options = {})
      v = @object.send(field)
      if v == true || v == false
        v = v ? 'Yes' : 'No'
        helpers.send(:image_tag, helpers.send(:url_for, :action => :asset, :path => %W(images auto_admin icon-#{v.downcase}.gif)), :alt => v, :title => v)
      else
        super
      end
    end
  end

  # Custom FormBuilder used to assemble the administered model list view.
  class TableBuilder < AutoAdmin::TableBuilder(FormBuilder)
    def table_header(field_type, field_name, options)
      klass = ''
      caption = yield + ' '

      if model.sortable_by? field_name
        sorting = @template.params[option(:sort_key)] == field_name.to_s
        sorted_reverse = sorting && @template.params["#{option(:sort_key)}_reverse".to_sym]
        link_will_reverse = sorting && !sorted_reverse

        klass = 'sorted ' + (sorted_reverse ? 'descending' : 'ascending') if sorting
        caption = link_to caption, @template.similar_list_page( option(:sort_key) => field_name, "#{option(:sort_key)}_reverse".to_sym => link_will_reverse )
      end

      %(<th class="#{klass}">#{caption}</th>)
    end
    def outer; %(<table cellspacing="0">); end
    def fieldset(style, title=nil)
      @column_num = 0
      super
    end
    def delete_button options={}
      wrap_field :delete_button, nil, options do |*a|
        <<-foo
        <a href="#" onclick="this.getElementsByTagName('input')[0].value = 'DELETE'; this.parentNode.parentNode.style.display = 'none'; return false;">
          <input type="hidden" value="" name="#{@object_name}[delete]" />
          #{helpers.send(:image_tag, helpers.send(:url_for, :action => :asset, :path => %w(images auto_admin icon_deletelink.gif)), :alt => ' [X]', :title => 'Delete')}
        </a>
        foo
      end
    end
    def table_cell(field_type, field_name, options)
      if field_name
        column = model.find_column(field_name)
        assoc = model.reflect_on_association(field_name.to_sym)
      end

      klass = assoc ? assoc.klass.name.underscore :
              column ? column.type :
              ''

      @column_num += 1
      do_link = 
        case opt = option(:link)
        when Array
          opt.any? {|el| (el === @column_num rescue false) || (el === field_name rescue false) }
        when Proc
          opt[@column_num, field_name, options]
        when true, false, nil
          opt
        else
          opt === @column_num
        end

      if do_link
        link = link_to( yield, :action => 'edit', :model => model_name, :id => @object.id )
        %(<th class="#{klass}">#{link}</th>)
      else
        %(<td class="#{klass}">#{yield}</td>)
      end
    end
  end
end
