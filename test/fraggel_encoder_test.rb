require 'fraggel'

class FraggelEncoderTest < Test::Unit::TestCase

  include Fraggel::Encoder

  def test_blank_line
    assert_equal "$-1\r\n", encode(nil)
  end

  def test_integer
    assert_equal ":123\r\n", encode(123)
  end

  def test_string
    assert_equal "$3\r\nfoo\r\n", encode("foo")
  end

  def test_error
    assert_equal "-ERR: test\r\n", encode(StandardError.new("test"))
  end

  def test_exception
    assert_equal "-ERR: test\r\n", encode(Exception.new("test"))
  end

  def test_true
    assert_equal ":1\r\n", encode(true)
  end

  def test_false
    assert_equal ":0\r\n", encode(false)
  end

  def test_array
    assert_equal "*1\r\n$3\r\nfoo\r\n", encode(["foo"])
  end

end
