require File.dirname(__FILE__)+"/helper"
require 'fraggle/connection'

class FraggleTransactionTest < Test::Unit::TestCase

  attr_reader :cn, :tmp, :valid, :done, :error

  def nop(attrs={})
    request(V::NOP, attrs)
  end

  def setup
    @cn = TestConn.new("127.0.0.1:0")
  end

  def test_tagging
    req, _ = nop
    assert_equal 0, cn.send_request(req).tag
    req, _ = nop
    assert_equal 1, cn.send_request(req).tag
    req, _ = nop
    assert_equal 2, cn.send_request(req).tag
  end

  def test_valid
    req, log =  nop
    req = cn.send_request(req)

    res = Fraggle::Response.new :tag => req.tag, :flags => F::VALID
    cn.receive_response(res)

    assert_equal [res], log.valid
    assert_equal [], log.done
  end

  def test_done
    req, log = nop
    req = cn.send_request(req)

    res = Fraggle::Response.new :tag => req.tag, :flags => F::DONE
    cn.receive_response(res)

    assert_equal [], log.valid
    assert_equal [req], log.done
  end

  def test_valid_and_done
    req, log = nop
    req = cn.send_request(req)

    res = Fraggle::Response.new :tag => req.tag, :flags => F::VALID|F::DONE
    cn.receive_response(res)

    assert_equal [res], log.valid
    assert_equal [req], log.done
  end

  def test_error
    req, log = nop
    req = cn.send_request(req)

    res = Fraggle::Response.new(
      :tag => req.tag,
      :flags => F::VALID|F::DONE,
      :err_code => E::OTHER
    )

    cn.receive_response(res)

    assert_equal [], log.valid
    assert_equal [], log.done
    assert_equal [res], log.error
  end

  def test_invalid_tag
    res = Fraggle::Response.new(
      :tag => 0,
      :flags => F::VALID|F::DONE,
      :err_code => E::OTHER
    )

    assert_nothing_raised do
      cn.receive_response(res)
    end
  end

  def test_done_deletes_callback
    req, log = nop
    req = cn.send_request(req)

    res = Fraggle::Response.new(:tag => req.tag, :flags => F::VALID|F::DONE)
    cn.receive_response(res)

    # This should be ignored
    cn.receive_response(res)

    assert_equal [res], log.valid
  end

  def test_error_with_done_deletes_callback
    req, log = nop
    req = cn.send_request(req)

    res = Fraggle::Response.new(
      :tag => req.tag,
      :flags => F::VALID|F::DONE,
      :err_code => E::OTHER
    )

    cn.receive_response(res)

    # This should be ignored
    cn.receive_response(res)

    assert_equal [res], log.error
  end

  def test_cannot_reuse_sent_request
    req, _ = nop
    req = cn.send_request(req)

    assert_raises Fraggle::Connection::SendError do
      cn.send_request(req)
    end
  end

  def test_cancel
    req, _ = nop
    req = cn.send_request(req)
    can = req.cancel

    canx = Fraggle::Response.new(:tag => can.tag, :flags => F::VALID|F::DONE)
    cn.receive_response(canx)
  end

  def test_cannot_cancel_more_than_once
    req, _ = nop
    req = cn.send_request(req)
    req.cancel

    assert_raises Fraggle::Connection::SendError do
      req.cancel
    end
  end

  def test_cancel_emits_done
    req, log = nop
    req = cn.send_request(req)
    can = req.cancel

    canx = Fraggle::Response.new(:tag => can.tag, :flags => F::VALID|F::DONE)
    cn.receive_response(canx)

    assert_equal [req], log.done
  end

  def test_disconnected
    a, al = nop
    a = cn.send_request(a)
    b, bl = nop
    b = cn.send_request(b)
    c, cl = nop
    c = cn.send_request(c)

    cn.unbind

    assert_equal 1, al.error.length
    assert_equal Fraggle::Connection::Disconnected, al.error.first

    assert_equal 1, bl.error.length
    assert_equal Fraggle::Connection::Disconnected, bl.error.first

    assert_equal 1, cl.error.length
    assert_equal Fraggle::Connection::Disconnected,  cl.error.first
  end

  def test_send_request_in_error_state
    cn.err = true

    req, log = nop
    req = cn.send_request(req)
    assert_equal nil, req.tag

    assert_equal nil, log.error.first
  end

  def test_liveness
    live = cn.post_init

    def cn.timer(_, &blk)
      blk.call
    end

    res = Fraggle::Response.new(:tag => live.tag, :rev => 1, :flags => F::VALID|F::DONE)
    cn.receive_response(res)
    assert ! cn.err?

    # Connections reuse tags and we're only responding to one request in this
    # test, so we know the next rev will use the previous tag
    res = Fraggle::Response.new(:tag => live.tag, :rev => 2, :flags => F::VALID|F::DONE)
    cn.receive_response(res)
    assert ! cn.err?
  end

  def test_not_alive
    live = cn.post_init

    def cn.timer(_, &blk)
      blk.call
    end

    res = Fraggle::Response.new(:tag => live.tag, :rev => 1, :flags => F::VALID|F::DONE)
    cn.receive_response(res)
    assert ! cn.err?

    res.tag += 1
    cn.receive_response(res)
    assert cn.err?
  end

end
