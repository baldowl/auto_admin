module AutoAdminDjangoTheme
  extend AutoAdmin::ThemeHelpers
  def self.directory(*subdirs)
    File.join(File.dirname(File.dirname(__FILE__)), 'themes', 'django', *subdirs)
  end

  helper do
    def history_link record
      link = "(Unnamed #{human_model(record.model).downcase})"
      link = record.object_label unless record.object_label.blank?
      link = link_to h(link), :model => record.model, :action => 'edit', :id => record.obj_id unless record.change == 'delete'
      link
    end
    def history_link_class record
      case record.change
        when 'add'; 'addlink'
        when 'delete'; 'deletelink'
        else 'changelink'
      end
    end
  end

  class FormProcessor < AutoAdminSimpleTheme::FormProcessor
  end
  class FormBuilder < AutoAdminSimpleTheme::FormBuilder
    def fieldset_class(style)
      case style
      when :fields then 'module aligned'
      when :table then 'module'
      end
    end
    def wrap_field(field_type, field_name, options)
      options[:class] = options[:class] ? options[:class].dup : ''
      column = model.find_column( field_name )
      assoc = model.reflect_on_association( field_name.to_sym )
      column_type = ( assoc && assoc.macro ) || ( column && column.type )
      case field_type
      when :text_field
        case column_type
        when :string
          options[:class] << ' vTextField'
          options[:size] ||= 30
          options[:maxlength] ||= column.limit
        when :integer
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

      if field_invalid? field_name
        %(<div class="form-row errors"><ul class="errorlist">) +
          field_errors( field_name ).map {|msg|
            %(<li>This field #{h msg}</li>)
          }.join +
          %(</ul>#{inner}</div>)
      else
        %(<div class="form-row">#{inner}</div>)
      end
    end
  end
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
      @first = true
      super
    end
    def table_cell(field_type, field_name, options)
      column = model.find_column(field_name)
      assoc = model.reflect_on_association(field_name.to_sym)

      klass = assoc ? assoc.klass.name.underscore :
              column ? column.type :
              ''

      was_first, @first = @first, false
      if was_first
        link = link_to( yield, :action => 'edit', :model => model_name, :id => @object.id )
        %(<th class="#{klass}">#{link}</th>)
      else
        %(<td class="#{klass}">#{yield}</td>)
      end
    end
  end
end

