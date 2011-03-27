require File.dirname(__FILE__)+"/helper"
require 'fraggle/client'

class FraggleClientTest < Test::Unit::TestCase

  attr_reader :c, :addrs

  def setup
    addr  = "127.0.0.1:0"
    cn = TestConn.new(addr)

    @addrs =["1.1.1.1:1", "2.2.2.2:2", "3.3.3.3:3"]
    @c  = Fraggle::Client.new(cn, @addrs)

    def @c.reconnect(host, port)
      @cn = TestConn.new("#{host}:#{port}")
    end
  end

  def test_send_valid_done
    req, log = request(V::NOP)
    req = c.send(req)

    res = Fraggle::Response.new :tag => req.tag, :value => "ing", :flags => F::VALID|F::DONE
    c.cn.receive_response(res)

    assert_equal [res], log.valid
    assert_equal [req], log.done
    assert_equal [], log.error
  end

  def test_send_error
    req, log = request(V::NOP)
    req = c.send(req)

    res = Fraggle::Response.new :tag => req.tag, :err_code => E::OTHER, :flags => F::VALID|F::DONE
    c.cn.receive_response(res)

    assert_equal [], log.valid
    assert_equal [], log.done
    assert_equal [res], log.error
  end

  def test_reconnect_without_pending_requests
    exp = @addrs.dup

    # Disconnect from 127.0.0.1:0
    c.cn.close_connection

    # Send a request to invoke reconnect
    req, log = request(V::NOP)
    req = c.send(req)

    # Fake reactor turn (only available in tests)
    c.cn.tick!

    assert exp.include?(c.cn.addr), "#{c.cn.addr.inspect} not in #{exp.inspect}"

    # If the client can handle an error, it should not mention it to the user.
    assert_equal [], log.error
  end

  def test_reconnect_with_pending_request
    exp = @addrs.dup

    # Send a request to invoke reconnect
    req, log = request(V::NOP)
    req = c.send(req)

    # Disconnect from 127.0.0.1:0
    c.cn.close_connection

    # Fake reactor turn (only available in tests)
    c.cn.tick!

    assert exp.include?(c.cn.addr), "#{c.cn.addr.inspect} not in #{exp.inspect}"

    # If the client can handle an error, it should not mention it to the user.
    assert_equal [], log.error
  end

  # retry
  def test_resend_pending_requests
    req, log = request(V::GET, :path => "/foo")
    req = c.resend(req)

    c.cn.close_connection

    assert_equal [req], c.cn.sent
  end

  def test_manage_offset
    req, log = request(V::WALK, :path => "/foo/*", :offset => 3)
    req = c.resend(req)

    res = Fraggle::Response.new :tag => req.tag, :flags => F::VALID
    c.cn.receive_response(res)

    c.cn.close_connection

    exp, _ = request(V::WALK, :tag => req.tag, :path => "/foo/*", :offset => 4)
    assert_equal [exp], c.cn.sent
  end

  def test_manage_limit
    req, log = request(V::WALK, :path => "/foo/*", :limit => 4)
    req = c.resend(req)

    res = Fraggle::Response.new :tag => req.tag, :flags => F::VALID
    c.cn.receive_response(res)

    c.cn.close_connection

    exp, _ = request(V::WALK, :tag => req.tag, :path => "/foo/*", :limit => 3)
    assert_equal [exp], c.cn.sent
  end

  # retry + rev (i.e. watch)
  # liveness check
  # monitor addrs
  # redirect

end
