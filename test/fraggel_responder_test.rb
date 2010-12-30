require 'fraggel'

class FraggelResponderTest < Test::Unit::TestCase

  class ResponseLogger
    include Fraggel::Responder

    attr_reader :log

    def initialize
      @log = []
    end

    def receive_response(value)
      @log << value
    end

  end

  attr_reader :responder

  def setup
    @responder = ResponseLogger.new
  end

  def test_integer
    responder.receive_event(:value, 1)
    assert_equal [1], responder.log
  end

  def test_string
    responder.receive_event(:value, "foo")
    assert_equal ["foo"], responder.log
  end

  def test_array
    responder.receive_event(:array, 1)
    responder.receive_event(:value, 2)
    assert_equal [[2]], responder.log
  end

  def test_nested_arrays
    responder.receive_event(:array, 1)
    responder.receive_event(:array, 2)
    responder.receive_event(:value, 2)
    responder.receive_event(:array, 1)
    responder.receive_event(:value, "foo")
    assert_equal [[[2, ["foo"]]]], responder.log
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


    assert_equal [1, ["a", ["b"], "c"], 2], responder.log
  end

end
