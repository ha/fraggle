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

    res = Fraggle::Response.new :tag => req.tag
    cn.receive_response(res)

    assert_equal [res], log.valid
    assert_equal [], log.done
  end

  def test_error
    req, log = nop
    req = cn.send_request(req)

    res = Fraggle::Response.new(
      :tag => req.tag,
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
      :err_code => E::OTHER
    )

    assert_nothing_raised do
      cn.receive_response(res)
    end
  end

  def test_deletes_callback
    req, log = nop
    req = cn.send_request(req)

    res = Fraggle::Response.new(:tag => req.tag)
    cn.receive_response(res)

    # This should be ignored
    cn.receive_response(res)

    assert_equal [res], log.valid
  end

  def test_error_deletes_callback
    req, log = nop
    req = cn.send_request(req)

    res = Fraggle::Response.new(
      :tag => req.tag,
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

  def test_ignores_responses_in_err_state
    a, al = nop
    a = cn.send_request(a)

    cn.unbind

    res = Fraggle::Response.new(:tag => a.tag)
    cn.receive_response(res)

    assert_equal [], al.valid
  end

  def test_send_request_in_error_state
    cn.err = true

    req, log = nop
    req = cn.send_request(req)
    assert_equal nil, req.tag

    assert_equal nil, log.error.first
  end
end
