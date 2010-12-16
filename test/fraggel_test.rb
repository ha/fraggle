require 'test/unit'
require 'stringio'
require 'fraggel'

class FraggelTest < Test::Unit::TestCase
  def test_response
    scanner = Fraggel::Scanner.new
    parts   = scanner.next("*1\r\n$3\r\nfoo\r\n")

    assert_equal ["foo"], parts
  end
  
  def test_response_multiple_elements
    scanner = Fraggel::Scanner.new
    parts   = scanner.next("*2\r\n$3\r\nfoo\r\n$3\r\nbar\r\n")

    assert_equal ["foo", "bar"], parts
  end
  
  def test_nested_response
    scanner = Fraggel::Scanner.new
    parts   = scanner.next("*3\r\n$3\r\nfoo\r\n*1\r\n$3\r\nbar\r\n$3\r\nbaz\r\n")

    assert_equal ["foo", ["bar"], "baz"], parts
  end
end
