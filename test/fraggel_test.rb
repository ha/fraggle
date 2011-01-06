require 'fraggel'

class FakeConn
  include Fraggel

  attr_reader :sent, :cbx

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
      :tag   => 1,
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
      :tag   => 1,
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
      :tag   => 1,
      :flags => Fraggel::Response::Flag::VALID | Fraggel::Response::Flag::DONE
    )

    c.receive_response(res)

    assert tests.empty?
  end

end
