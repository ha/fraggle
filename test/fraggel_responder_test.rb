require 'fraggel'

class FraggelResponderTest < Test::Unit::TestCase

  attr_reader :responder
  attr_reader :log

  def setup
    @log = []
    @responder = Fraggel::Responder.new do |x|
      @log << x
    end
  end

  def test_integer
    responder.receive_event(:value, 1)
    assert_equal [1], log
  end

  def test_string
    responder.receive_event(:value, "foo")
    assert_equal ["foo"], log
  end

  def test_array
    responder.receive_event(:array, 1)
    responder.receive_event(:value, 2)
    assert_equal [[2]], log
  end

  def test_nested_arrays
    responder.receive_event(:array, 1)
    responder.receive_event(:array, 2)
    responder.receive_event(:value, 2)
    responder.receive_event(:array, 1)
    responder.receive_event(:value, "foo")
    assert_equal [[[2, ["foo"]]]], log
  end

  def test_deep_nested_array
    # Arrays are indented for clarity
    responder.receive_event(:value, 1)
    responder.receive_event(:array, 3)
      responder.receive_event(:value, "a")
      responder.receive_event(:array, 1)
        responder.receive_event(:value, "b")
      responder.receive_event(:value, "c")
    responder.receive_event(:value, 2)


    assert_equal [1, ["a", ["b"], "c"], 2], log
  end

end
