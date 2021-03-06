require File.expand_path(File.dirname(__FILE__)+"/helper")
require 'fraggle/client'

class FraggleClientTest < Test::Unit::TestCase

  attr_reader :c

  def setup
    addr = "127.0.0.1:0"
    cn   = TestConn.new(addr)

    @addrs  = ["1.1.1.1:1", "2.2.2.2:2", "3.3.3.3:3"]
    @c      = Fraggle::Client.allocate

    def @c.reconnect(addr)
      @cn = TestConn.new(addr)
    end

    def @c.monitor_addrs
      # do nothing
    end

    @c.__send__(:initialize, cn, @addrs)
  end

  def test_response_error
    req, log = request(V::REV)

    c.send(req, &log)

    res = reply(req.tag, :err_code => E::OTHER)
    c.cn.receive_response(res)

    assert_equal [[nil, C::ResponseError.new(res)]], log
  end

  def test_reconnect_without_pending_requests
    exp = @addrs.dup

    # Disconnect from 127.0.0.1:0
    c.cn.close_connection

    # Send a request to invoke reconnect
    req, log = request(V::REV)
    c.send(req, &log)

    # Fake reactor turn (only available in tests)
    c.cn.tick!

    assert exp.include?(c.cn.addr), "#{c.cn.addr.inspect} not in #{exp.inspect}"

    # If the client can handle an error, it should not mention it to the user.
    assert_equal [[nil, C::DisconnectedError.new("127.0.0.1:0")]], log
  end

  def test_reconnect_with_pending_request
    exp = @addrs.dup

    # Send a request to invoke reconnect
    req, log = request(V::REV)
    c.send(req, &log)

    # Disconnect from 127.0.0.1:0
    c.cn.close_connection

    # Fake reactor turn (only available in tests)
    c.cn.tick!

    assert exp.include?(c.cn.addr), "#{c.cn.addr.inspect} not in #{exp.inspect}"

    assert_equal [[nil, C::DisconnectedError.new("127.0.0.1:0")]], log
  end

  def test_reconnect_with_multiple_pending_requests
    exp = @addrs.dup

    # Send a request to invoke reconnect
    req, loga = request(V::REV)
    c.send(req, &loga)

    req, logb = request(V::REV)
    c.send(req, &logb)

    # Disconnect from 127.0.0.1:0
    c.cn.close_connection

    # Fake reactor turn (only available in tests)
    c.cn.tick!

    assert exp.include?(c.cn.addr), "#{c.cn.addr.inspect} not in #{exp.inspect}"

    # If the client can handle an error, it should not mention it to the user.
    assert_equal [[nil, C::DisconnectedError.new("127.0.0.1:0")]], loga
    assert_equal [[nil, C::DisconnectedError.new("127.0.0.1:0")]], logb
  end

  def test_resend_pending_requests
    req, log = request(V::GET, :path => "/foo")
    c.resend(req, &log)

    c.cn.close_connection

    assert_equal [req], c.cn.sent
  end

  def test_idemp_pending_requests
    one, olog = request(V::SET, :rev => 1, :path => "/foo", :value => "bar")
    c.idemp(one, &olog)

    zero, zlog = request(V::SET, :rev => 0, :path => "/foo", :value => "bar")
    c.idemp(zero, &zlog)

    c.cn.close_connection

    assert_equal [one], c.cn.sent

    assert_equal [[nil, C::DisconnectedError.new("127.0.0.1:0")]], zlog
  end

  def test_idemp_unhandled_error
    req, log = request(V::SET, :path => "/foo", :value => "bar", :rev => Fraggle::Client::MaxInt64)
    c.idemp(req, &log)

    res = reply(req.tag, :err_code => E::OTHER)
    c.cn.receive_response(res)

    assert_equal [[nil, C::ResponseError.new(res)]], log
  end

  ###
  # Sugar

  def last_sent
    c.cn.sent.last
  end

  def assert_verb(exp, name, *args)
    called = false
    blk = Proc.new { called = true }
    req = c.__send__(name, *args, &blk)
    exp[:tag] = req.tag
    assert_equal exp, last_sent.to_hash

    c.cn.receive_response(reply(req.tag))
    assert called
  end

  def test_set
    exp = {
      :verb => V::SET,
      :rev => 0,
      :path => "/foo",
      :value => "bar"
    }

    assert_verb exp, :set, 0, "/foo", "bar"
  end

  def test_get
    exp = {
      :verb => V::GET,
      :rev => 0,
      :path => "/foo"
    }

    assert_verb exp, :get, 0, "/foo"
  end

  def test_del
    exp = {
      :verb => V::DEL,
      :rev => 0,
      :path => "/foo"
    }

    assert_verb exp, :del, 0, "/foo"
  end

  def test_getdir
    exp = {
      :verb => V::GETDIR,
      :rev => 0,
      :path => "/foo",
      :offset => 0
    }

    assert_verb exp, :_getdir, 0, "/foo", 0
  end

  def test_rev
    exp = {
      :verb => V::REV
    }

    assert_verb exp, :rev
  end

  def test_stat
    exp = {
      :rev  => 0,
      :verb => V::STAT,
      :path => "/foo"
    }

    assert_verb exp, :stat, 0, "/foo"
  end

  def test_walk
    exp = {
      :verb => V::WALK,
      :rev => 0,
      :path => "/foo/*",
      :offset => 0
    }

    assert_verb exp, :_walk, 0, "/foo/*", 0
  end

  def test_wait
    exp = {
      :verb => V::WAIT,
      :rev => 0,
      :path => "/foo/*"
    }

    assert_verb exp, :wait, 0, "/foo/*"
  end

  def test_wait
    exp = {
      :verb => V::ACCESS,
      :value => "abc"
    }

    assert_verb exp, :access, "abc"
  end

end
