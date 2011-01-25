require 'fraggel'

##
# This is used to test core functionality that the live integration tests will
# rely on.
class FakeConn
  include Fraggel

  attr_reader   :sent, :cbx
  attr_accessor :tag

  def initialize
    @sent = ""
    super("127.0.0.1", :assemble => false)
    post_init
  end

  def send_data(data)
    @sent << data
  end
end

class CoreTest < Test::Unit::TestCase

  def test_sending_data
    c = FakeConn.new

    c.call(Fraggel::Request::Verb::NOOP)

    req = Fraggel::Request.new(
      :tag   => c.tag,
      :verb  => Fraggel::Request::Verb::NOOP
    )

    buf = req.encode
    pre = [buf.length].pack("N")

    assert_equal pre+buf, c.sent
  end

  def test_receive_small_buffered_data
    count = 0
    c = FakeConn.new

    tag = c.call(Fraggel::Request::Verb::WATCH, :path => "**") do |e|
      count += 1
    end

    res = Fraggel::Response.new(
      :tag   => tag,
      :flags => Fraggel::Response::Flag::VALID
    )

    exp   = 10
    buf   = res.encode
    pre   = [buf.length].pack("N")
    bytes = (pre+buf)*exp

    # Chunk bytes to receive_data in some arbitrary size
    0.step(bytes.length, 3) do |n|
      c.receive_data(bytes.slice!(0, n))
    end

    assert_equal 10, count
  end

  def test_receive_large_buffered_data
    count = 0
    c = FakeConn.new

    tag = c.call(Fraggel::Request::Verb::WATCH, :path => "**") do |e|
      count += 1
    end

    res = Fraggel::Response.new(
      :tag   => tag,
      :flags => Fraggel::Response::Flag::VALID
    )

    exp   = 10
    buf   = res.encode
    pre   = [buf.length].pack("N")
    bytes = (pre+buf)*exp

    c.receive_data(bytes)

    assert_equal 10, count
  end

  def test_callback_without_done
    c = FakeConn.new

    valid = lambda do |e|
      assert_kind_of Fraggel::Response, e
    end

    done = lambda do |e|
      assert false, "Unreachable"
    end

    tests = [valid, done]

    c.call(Fraggel::Request::Verb::NOOP) do |e|
      tests.shift.call(e)
    end

    res = Fraggel::Response.new(
      :tag   => c.tag,
      :flags => Fraggel::Response::Flag::VALID | Fraggel::Response::Flag::DONE
    )

    c.receive_response(res)

    assert_equal 1, tests.length
  end

  def test_callback_with_done
    c = FakeConn.new

    valid = lambda do |e, done|
      assert_kind_of Fraggel::Response, e
      assert_equal false, done
    end

    done = lambda do |e, done|
      assert_nil e
      assert_equal true, done
    end

    tests = [valid, done]

    c.call(Fraggel::Request::Verb::NOOP) do |e, done|
      tests.shift.call(e, done)
    end

    res = Fraggel::Response.new(
      :tag   => c.tag,
      :flags => Fraggel::Response::Flag::VALID | Fraggel::Response::Flag::DONE
    )

    c.receive_response(res)

    assert tests.empty?
  end

  def test_no_callback
    c = FakeConn.new
    c.call(Fraggel::Request::Verb::NOOP)

    res = Fraggel::Response.new(
      :tag   => c.tag,
      :flags => Fraggel::Response::Flag::VALID | Fraggel::Response::Flag::DONE
    )

    assert_nothing_raised do
      c.receive_response(res)
    end
  end

  def test_no_callback_gc
    c = FakeConn.new
    c.call(Fraggel::Request::Verb::NOOP)

    res = Fraggel::Response.new(
      :tag   => c.tag,
      :flags => Fraggel::Response::Flag::VALID | Fraggel::Response::Flag::DONE
    )

    c.receive_response(res)

    assert ! c.cbx.has_key?(1)
  end

  def test_callback_gc
    c = FakeConn.new
    c.call(Fraggel::Request::Verb::NOOP) {}

    res = Fraggel::Response.new(
      :tag   => c.tag,
      :flags => Fraggel::Response::Flag::VALID
    )

    c.receive_response(res)

    assert c.cbx.has_key?(c.tag)

    res.flags = Fraggel::Response::Flag::DONE
    c.receive_response(res)

    assert ! c.cbx.has_key?(c.tag)
  end

  def test_call_returns_tag
    c = FakeConn.new
    assert_equal 0, c.call(Fraggel::Request::Verb::NOOP)
    assert_equal 1, c.call(Fraggel::Request::Verb::NOOP)
  end

  def test_call_increments_tag
    c = FakeConn.new
    c.call(Fraggel::Request::Verb::NOOP)
    assert_equal 0, c.tag
    c.call(Fraggel::Request::Verb::NOOP)
    assert_equal 1, c.tag
    c.call(Fraggel::Request::Verb::NOOP)
    assert_equal 2, c.tag
    c.call(Fraggel::Request::Verb::NOOP)
    assert_equal 3, c.tag
    c.call(Fraggel::Request::Verb::NOOP)
    assert_equal 4, c.tag
    c.call(Fraggel::Request::Verb::NOOP)
    assert_equal 5, c.tag
    c.call(Fraggel::Request::Verb::NOOP)
    assert_equal 6, c.tag
    c.call(Fraggel::Request::Verb::NOOP)
    assert_equal 7, c.tag
    c.call(Fraggel::Request::Verb::NOOP)
    assert_equal 8, c.tag
    c.call(Fraggel::Request::Verb::NOOP)
    assert_equal 9, c.tag
  end

  def test_no_overlap_in_tags
    c = FakeConn.new

    c.cbx[0] = Proc.new {}
    assert_equal 1, c.call(Fraggel::Request::Verb::NOOP)
  end

  def test_rollover_tag_when_maxed_out
    c = FakeConn.new
    c.tag = Fraggel::MaxInt32
    c.call(Fraggel::Request::Verb::NOOP)

    assert_equal  Fraggel::MinInt32, c.tag
  end

end
