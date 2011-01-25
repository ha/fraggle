require 'fraggle'

##
# This is used to test core functionality that the live integration tests will
# rely on.
class FakeConn
  include Fraggle

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

  attr_reader :c

  V = Fraggle::Request::Verb
  F = Fraggle::Response::Flag

  def setup
    @c = FakeConn.new
  end

  def reply(attrs={})
    attrs[:tag] = c.tag
    attrs[:flags] ||= 0
    attrs[:flags] |= F::VALID
    res = Fraggle::Response.new(attrs)
    c.receive_response(res)
    res
  end

  def reply!(attrs={})
    attrs[:flags] = F::DONE
    reply(attrs)
  end

  def test_sending_data
    c.call(V::NOOP)

    req = Fraggle::Request.new(
      :tag   => c.tag,
      :verb  => V::NOOP
    )

    buf = req.encode
    pre = [buf.length].pack("N")

    assert_equal pre+buf, c.sent
  end

  def test_receive_small_buffered_data
    count = 0

    tag = c.call(V::WATCH, :path => "**") do |e|
      count += 1
    end

    res = Fraggle::Response.new(
      :tag   => tag,
      :flags => F::VALID
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

    tag = c.call(V::WATCH, :path => "**") do |e|
      count += 1
    end

    res = Fraggle::Response.new(
      :tag   => tag,
      :flags => F::VALID
    )

    exp   = 10
    buf   = res.encode
    pre   = [buf.length].pack("N")
    bytes = (pre+buf)*exp

    c.receive_data(bytes)

    assert_equal 10, count
  end

  def test_callback_without_done
    valid = lambda do |e|
      assert_kind_of Fraggle::Response, e
    end

    done = lambda do |e|
      assert false, "Unreachable"
    end

    tests = [valid, done]

    c.call(V::NOOP) do |e|
      tests.shift.call(e)
    end
    reply!

    assert_equal 1, tests.length
  end

  def test_callback_with_done
    valid = lambda do |e, done|
      assert_kind_of Fraggle::Response, e
      assert_equal false, done
    end

    done = lambda do |e, done|
      assert_nil e
      assert_equal true, done
    end

    tests = [valid, done]

    c.call(V::NOOP) do |e, done|
      tests.shift.call(e, done)
    end

    reply!
    assert tests.empty?
  end

  def test_no_callback
    c.call(V::NOOP)

    assert_nothing_raised do
      reply!
    end
  end

  def test_no_callback_gc
    c.call(V::NOOP)
    reply!

    assert ! c.cbx.has_key?(1)
  end

  def test_callback_gc
    c.call(V::NOOP) {}
    reply

    assert c.cbx.has_key?(c.tag)

    reply!

    assert ! c.cbx.has_key?(c.tag)
  end

  def test_call_returns_tag
    assert_equal 0, c.call(V::NOOP)
    assert_equal 1, c.call(V::NOOP)
  end

  def test_call_increments_tag
    c.call(V::NOOP)
    assert_equal 0, c.tag
    c.call(V::NOOP)
    assert_equal 1, c.tag
    c.call(V::NOOP)
    assert_equal 2, c.tag
    c.call(V::NOOP)
    assert_equal 3, c.tag
    c.call(V::NOOP)
    assert_equal 4, c.tag
    c.call(V::NOOP)
    assert_equal 5, c.tag
    c.call(V::NOOP)
    assert_equal 6, c.tag
    c.call(V::NOOP)
    assert_equal 7, c.tag
    c.call(V::NOOP)
    assert_equal 8, c.tag
    c.call(V::NOOP)
    assert_equal 9, c.tag
  end

  def test_no_overlap_in_tags
    c.cbx[0] = Proc.new {}
    assert_equal 1, c.call(V::NOOP)
  end

  def test_rollover_tag_when_maxed_out
    c.tag = Fraggle::MaxInt32
    c.call(V::NOOP)

    assert_equal  Fraggle::MinInt32, c.tag
  end

end
