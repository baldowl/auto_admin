require File.dirname(__FILE__) + '/test_helper'

class BuilderTest < Test::Unit::TestCase
  def setup
    reset!
    @template = build_template
    @ed = Actor.find(3)
  end
  def build_template
    template = ''
    class << template
      def h(v) v; end
      include ActionView::Helpers::FormHelper
    end
    template
  end
  private :build_template
  def test_dummy; end
end
class SimpleBuilderTest < BuilderTest
  def test_text_field
    builder = SimpleAdminFormBuilder.new( 'my_actor', @ed, @template, {}, binding )
    html = builder.text_field( :first_name, :required => true )
    assert_equal %(<label class="required" for="my_actor_first_name">First name:</label> <input class="required" id="my_actor_first_name" name="my_actor[first_name]" size="30" type="text" value="ED" /><br />), html
  end
end

