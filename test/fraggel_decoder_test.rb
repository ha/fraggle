require 'fraggel'

class FraggelDecoderTest < Test::Unit::TestCase

  class DecodeLogger
    include Fraggel::Decoder

    attr_reader :log

    def initialize
      @log = []
    end

    def receive_event(*args)
      @log << args
    end
  end


  attr_reader :parser

  def setup
    @parser = DecodeLogger.new
  end

  def test_blank_line
    parser.receive_data("\r\n")
    parser.receive_data("\r")
    parser.receive_data("\n")

    assert_equal [], parser.log
  end

  def test_blank_poison
    assert_raise(Fraggel::Decoder::Poisioned) do
      parser.receive_data("\n")
    end
  end

  def test_read_integer
    ":123".each_char do |c|
      parser.receive_data(c)
    end
    assert_equal [], parser.log

    parser.receive_data("\r")
    assert_equal [], parser.log

    parser.receive_data("\n")
    assert_equal [[:value, 123]], parser.log
  end

  def test_read_poisoned_integer
    parser.receive_data(":1")
    assert_raise(Fraggel::Decoder::Poisioned) do
      parser.receive_data("X")
    end
  end

  def test_read_string
    "$4\r\nping".each_char do |c|
      parser.receive_data(c)
    end
    assert_equal [], parser.log

    parser.receive_data("\r")
    assert_equal [], parser.log

    parser.receive_data("\n")
    assert_equal [[:value, "ping"]], parser.log
  end

  def test_read_poisoned_string
    parser.receive_data("$1")
    assert_raise(Fraggel::Decoder::Poisioned) do
      parser.receive_data("X")
    end
  end

  def test_read_true
    "+OK".each_char do |c|
      parser.receive_data(c)
    end
    assert_equal [], parser.log

    parser.receive_data("\r")
    assert_equal [], parser.log

    parser.receive_data("\n")
    assert_equal [[:status, "OK"]], parser.log
  end

  def test_read_false
    "-ERR".each_char do |c|
      parser.receive_data(c)
    end
    assert_equal [], parser.log

    parser.receive_data("\r")
    assert_equal [], parser.log

    parser.receive_data("\n")
    assert_equal [[:error, "ERR"]], parser.log
  end

  def test_read_array
    "*1".each_char do |c|
      parser.receive_data(c)
    end
    assert_equal [], parser.log

    parser.receive_data("\r")
    assert_equal [], parser.log

    parser.receive_data("\n")
    assert_equal [[:array, 1]], parser.log
  end

  def test_all_types_together
    "*2\r\n:1\r\n$3\r\nfoo\r\n+OK\r\n-ERR\r\n".each_char do |c|
      parser.receive_data(c)
    end

    expected = [
      [:array, 2],
      [:value, 1],
      [:value, "foo"],
      [:status, "OK"],
      [:error, "ERR"]
    ]

    assert_equal expected, parser.log
  end

end
