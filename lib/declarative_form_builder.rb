class DeclarativeFormBuilder
  def initialize(object_name, object, erb_self, options, proc)
    @erb, @binding, @options = erb_self, options[:binding] || proc.binding, options
    @inner = (options[:inner_builder] || ActionView::Helpers::FormBuilder).new(object_name, object, erb_self, options, proc)
    @erb.concat("\n", @binding)
  end
  %w(object inner_fields_for table_fields_for with_object).each do |meth|
    class_eval <<-end_src, __FILE__, __LINE__
      def #{meth}(*args, &block); @inner.#{meth}(*args, &block); end
    end_src
  end
  def method_missing(method, *args, &block)
    e = 'end_' + method.to_s
    # If there's an end_ variant of the method, we'll use the block
    # ourselves. If not, the block must be intended for the underlying
    # method.
    if @inner.respond_to?(e)
      buffer! @inner.send(method, *args)
      if block_given?
        @options[:indent] += 1 if @options[:indent]
        yield
        @options[:indent] -= 1 if @options[:indent]
        buffer! @inner.send(e)
      end
    else
      buffer! @inner.send(method, *args, &block)
    end
    nil
  end
  def buffer!(content)
    pre = @options[:indent] ? ('  ' * @options[:indent]) : ''
    @erb.concat(pre + content + "\n", @binding) if content && content != ''
  end
end
