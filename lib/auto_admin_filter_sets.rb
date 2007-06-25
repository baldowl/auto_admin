
module AutoAdmin
  class SimpleFilterSet
    attr_reader :klass, :column
    def initialize klass, column
      @klass, @column = klass, column
    end
    def name
      column.name
    end
    def all_option
      { :name => '*', :label => all_label }
    end
    def all_label; 'All'; end
    def option option_name
      return all_option if option_name == '*'
      other_option( option_name ) || {}
    end
    def other_option option_name
      other_options.find {|o| o[:name] == option_name }
    end
    def options
      [ all_option ] + other_options
    end
    def sql option_name
      return [] if option_name == '*'
      sql_from_string option_name
    end
    def sql_from_string option_name
      sql_from_value option_name
    end
    def sql_from_value option_name
      ["#{column.name} = ?", option_name]
    end
    def build_option name, label
      { :name => name.to_s, :label => label, :sql => sql_from_value( name ) }
    end
  end
  class CustomFilterSet < SimpleFilterSet
    def initialize klass, column, options, &block
      super klass, column
      @options, @block = options, block
    end
    def sql_from_string option_name
      @block ? @block.call( option_name ) : super
    end
    def other_options
      a = []
      options = @options
      options = options.call if options.respond_to?( :call )
      options.each do |k,v|
        o = build_option( k, v )
        o[:sql] = @block.call( k ) unless @block.nil?
        a << o
      end
      a.sort_by {|i| i[:label] }
    end
  end
  class EmptyFilterSet < SimpleFilterSet
    def other_options; []; end
  end
  class DynamicFilterSet < SimpleFilterSet
    def other_option option_name
      option_from_object( object_from_option_name( option_name ) )
    end
    def other_options
      objects.map { |o| option_from_object( o ) }
    end
  end
  class StringFilterSet < DynamicFilterSet
    def objects
      # FIXME: This really needn't load objects for every row in the
      # DB...
      klass.find(:all).map {|o| o.send column.name }.sort.uniq
    end
    def object_from_option_name option_name
      option_name
    end
    def option_from_object obj
      build_option obj, obj
    end
  end
  class AssociationFilterSet < DynamicFilterSet
    attr_reader :assoc
    def initialize klass, assoc
      @assoc = assoc
      column = sql_column
      column = yield column if block_given?
      super klass, column
    end
    def name
      assoc.name.to_s
    end
    def sql_column
      assoc.association_foreign_key
    end
    def objects
      assoc.klass.find :all
    end
    def object_from_option_name option_name
      assoc.klass.find option_name.to_i
    end
    def option_from_object obj
      build_option obj.id, obj.to_label
    end
    def sql_from_string option_name
      sql_from_value option_name.to_i
    end
  end
  class MultiAssociationFilterSet < AssociationFilterSet
    def sql_from_value option_name
      ["EXISTS(SELECT * FROM #{assoc.options[:join_table]} WHERE #{assoc.primary_key_name} = #{assoc.active_record.primary_key} AND #{assoc.association_foreign_key} = ?)", option_name]
    end
  end
  class BooleanFilterSet < SimpleFilterSet
    def other_options
      [ build_option( true, 'Yes' ), build_option( false, 'No' ) ]
    end
    def sql_from_string option_name
      sql_from_value( option_name == 'true' )
    end
  end
  class DateFilterSet < SimpleFilterSet
    def all_label; 'Any date'; end
    def other_options
      [ build_option( 'today', 'Today' ),
        build_option( 'week', 'Past 7 days' ),
        build_option( 'month', 'This month' ),
        build_option( 'year', 'This year' ) ]
    end
    def sql_from_value option_name
      {
        'today' => ["#{column.name} BETWEEN ? AND ?", Time.now.midnight, Time.now.tomorrow.midnight],
        'week' => ["#{column.name} BETWEEN ? AND ?", 7.days.ago.midnight, Time.now.tomorrow.midnight],
        'month' => ["#{column.name} BETWEEN ? AND ?", Time.now.beginning_of_month, Time.now.next_month.beginning_of_month],
        'year' => ["#{column.name} BETWEEN ? AND ?", Time.now.beginning_of_year, Time.now.next_year.beginning_of_year]
      }[option_name]
    end
  end
end

