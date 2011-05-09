require File.expand_path(File.dirname(__FILE__)+"/helper")
require 'fraggle/connection'

class FraggleTransactionTest < Test::Unit::TestCase

  attr_reader :cn

  def setup
    @cn = TestConn.new("127.0.0.1:0")
  end

  def test_tagging
    req, _ = request(V::REV)
    assert_equal 0, cn.send_request(req, _).tag
    req, _ = request(V::REV)
    assert_equal 1, cn.send_request(req, _).tag
    req, _ = request(V::REV)
    assert_equal 2, cn.send_request(req, _).tag
  end

  def test
    req, log = request(V::REV)

    cn.send_request(req, log)

    res = reply(req.tag)
    cn.receive_response(res)

    assert_equal [[res, nil]], log
  end

  def test_error
    req, log = request(V::REV)

    cn.send_request(req, log)

    res = reply(req.tag, :err_code => E::OTHER)
    cn.receive_response(res)

    err = C::ResponseError.new(res)
    assert_equal [[nil, err]], log
  end

  def test_i_tag
    res = reply(0, :err_code => E::OTHER)

    assert_nothing_raised do
      cn.receive_response(res)
    end
  end

  def test_deletes_callback
    req, log = request(V::REV)

    cn.send_request(req, log)

    res = reply(req.tag)
    cn.receive_response(res)

    # This should be ignored
    cn.receive_response(res)

    assert_equal [[res, nil]], log
  end

  def test_error_deletes_callback
    req, log = request(V::REV)

    cn.send_request(req, log)

    res = reply(req.tag, :err_code => E::OTHER)
    cn.receive_response(res)

    # This should be ignored
    cn.receive_response(res)

    assert_equal [[nil, C::ResponseError.new(res)]], log
  end

  def test_cannot_reuse_sent_request
    req, _ = request(V::REV)
    cn.send_request(req, _)

    assert_raises C::SendError do
      cn.send_request(req, _)
    end
  end

  def test_disconnect_with_pending_requests
    a, al = request(V::REV)
    a = cn.send_request(a, al)
    b, bl = request(V::REV)
    b = cn.send_request(b, bl)
    c, cl = request(V::REV)
    c = cn.send_request(c, cl)

    cn.unbind

    assert_equal [[nil, C::DisconnectedError.new("127.0.0.1:0")]], al
    assert_equal [[nil, C::DisconnectedError.new("127.0.0.1:0")]], bl
    assert_equal [[nil, C::DisconnectedError.new("127.0.0.1:0")]], cl
  end

  def test_send_when_disconnected
    cn.unbind

    req, log = request(V::REV)
    ret = cn.send_request(req, log)

    assert_equal req, ret

    cn.tick!

    assert_equal [[nil, C::DisconnectedError.new("127.0.0.1:0")]], log
  end
end
