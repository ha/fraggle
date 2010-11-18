require 'test/unit'
require 'stringio'
require 'fraggel'

class FraggelTest < Test::Unit::TestCase
  def test_response
    scanner = Fraggel::Scanner.new
    parts   = scanner.next("*1\r\n$3\r\nfoo\r\n")

    assert_equal ["foo"], parts
  end
end
