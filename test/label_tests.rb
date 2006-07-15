require File.dirname(__FILE__) + '/test_helper'

class ObjectLabelTest < Test::Unit::TestCase
  def test_object
    assert !Object.new.to_label.empty?
  end
  def test_label
    o = Object.new
    class << o; def label() 'foo'; end; def name() 'bar' end; def to_s() 'baz' end; end
    assert_equal "foo", o.to_label
  end
  def test_name
    o = Object.new
    class << o; def name() 'bar'; end; def to_s() 'baz' end; end
    assert_equal "bar", o.to_label
  end
  def test_overridden_to_label
    o = Object.new
    class << o; def to_label() 'xyzzy'; end; end
    assert_equal "xyzzy", o.to_label
  end
  def test_to_s
    o = Object.new
    class << o; def to_s() 'baz'; end; end
    assert_equal "baz", o.to_label
  end
  def test_symbol
    assert_equal "something", :something.to_label
  end
end

