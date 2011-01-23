require 'fraggel'

class FakeConn
  include Fraggel

  attr_reader   :sent, :cbx
  attr_accessor :tag

  def initialize
    @sent = ""
    post_init
  end

  def send_data(data)
    @sent << data
  end
end

class FraggelTest < Test::Unit::TestCase

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

  def test_callback_without_done
    c = FakeConn.new

    valid = lambda do |e|
      assert_not_nil e
    end

    done = lambda do |e|
      assert false, "Unreachable"
    end

    tests = [valid, done]

    c.call(Fraggel::Request::Verb::NOOP) do |e|
      tests.shift.call(e, false)
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
      assert_not_nil e
      assert ! done
    end

    done = lambda do |e, done|
      assert_nil e
      assert done
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

  def test_buffered_data
  end

end
