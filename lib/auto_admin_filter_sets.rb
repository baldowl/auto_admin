module AutoAdmin
  # The simplest, base filter class, used to handle the translation from the
  # options set for a given column to the necessary SQL-like fragments.
  #
  # The options are triplets of name, label and SQL-like frament, stored into
  # an hash; the name is used to retrive the chosen trio. See
  # AutoAdminConfiguration::ClassMethods::filter_options_for method for an
  # example use (even if that code use CustomFilterSet).
  class SimpleFilterSet
    attr_reader :klass, :column

    # +klass+ is the filtered model class and +column+ is the name (string or
    # symbol) of the filtered on column.
    def initialize klass, column
      @klass, @column = klass, column
    end

    # Name of the column for which this filter has been created.
    def name
      column.name
    end

    # The simple "I want everything" option.
    def all_option
      { :name => '*', :label => all_label }
    end
    def all_label; 'All'; end

    # Returns the named option, delegating most of the work to other_option.
    def option option_name
      return all_option if option_name == '*'
      other_option( option_name ) || {}
    end

    # Returns the named option.
    def other_option option_name
      other_options.find {|o| o[:name] == option_name }
    end

    # Every option managed by this filter.
    def options
      [ all_option ] + other_options
    end

    # Returns the SQL-like frament deriving from the named option, delegating
    # most of the work to sql_from_string.
    def sql option_name
      return [] if option_name == '*'
      sql_from_string option_name
    end

    # Delegates everything to sql_from_value, so we could say it's just an
    # alias, but derived classes behave differently.
    def sql_from_string option_name
      sql_from_value option_name
    end

    # Returns the SQL-like frament for the named option
    def sql_from_value option_name
      ["#{column.name} = ?", option_name]
    end

    # +name+ is actually the value used in the SQL-like frament.
    def build_option name, label
      { :name => name.to_s, :label => label, :sql => sql_from_value( name ) }
    end
  end

  # User customizable filter class
  class CustomFilterSet < SimpleFilterSet
    # +klass+ is the filtered model class, +column+ is the name (string or
    # symbol) of the filtered on column, +options+ is a hash (value, label).
    # The +block+ is totally optional and if present will be used to
    # manipulate each +options+ pair while building the SQL-like fragments.
    def initialize klass, column, options, &block
      super klass, column
      @options, @block = options, block
    end

    # Returns the SQL-like frament for the named option using the optional
    # block.
    def sql_from_string option_name
      @block ? @block.call( option_name ) : super
    end

    # Builds up an array of triplets starting from the +options+ hash, calling
    # the optional block for each hash pair.
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

  # Base class for filters which build up the option set dynamically from the
  # column's values stored in the database.
  class DynamicFilterSet < SimpleFilterSet
    # Returns the named option, building it up on the fly.
    def other_option option_name
      option_from_object( object_from_option_name( option_name ) )
    end

    # Builds up the array of options calculating them on the fly.
    def other_options
      objects.map { |o| option_from_object( o ) }
    end
  end

  # Filter class for string objects. Beware of its inefficiency.
  class StringFilterSet < DynamicFilterSet
    # Every value stored in the database; potentially devastating.
    def objects
      # FIXME: This really needn't load objects for every row in the
      # DB...
      klass.find(:all).map {|o| o.send column.name }.sort.uniq
    end

    # Given the option name, returns the object whose colum has the value
    # represented by +option_name+. For this filter, this is a no-op method
    # returning just +option_name+.
    def object_from_option_name option_name
      option_name
    end

    # Builds up the needed triplet.
    def option_from_object obj
      build_option obj, obj
    end
  end

  # An interesting example of dynamic filter used on the N-1 associations.
  class AssociationFilterSet < DynamicFilterSet
    attr_reader :assoc

    # +assoc+ is the value returned by +reflect_on_association+ for the
    # filtered column.
    def initialize klass, assoc
      @assoc = assoc
      column = sql_column
      column = yield column if block_given?
      super klass, column
    end

    # The name of the filtered association, i.e., the filtered column.
    def name
      assoc.name.to_s
    end

    # The database table column to use in the SQL-like frament, i.e., the
    # foreing key.
    def sql_column
      assoc.association_foreign_key
    end

    # Every object potentially connected with the administered model object.
    def objects
      assoc.klass.find :all
    end

    # Given the option name, returns the object whose id is the value
    # represented by +option_name+, i.e., the associated object.
    def object_from_option_name option_name
      assoc.klass.find option_name.to_i
    end

    # Builds up the needed triplet.
    def option_from_object obj
      build_option obj.id, obj.to_label
    end

    # Returns the SQL-like frament for the named option.
    def sql_from_string option_name
      sql_from_value option_name.to_i
    end
  end

  # Dynamic filter used on 1-N and N-N associations.
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
