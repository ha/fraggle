require 'fraggle'

class RecConn
  include Fraggle

  attr_reader :store, :recs

  def initialize
    super("1:1", :assemble => true)
    post_init
    @store = {}
    @recs  = []
  end

  def get(path, sid=0, &blk)
    res = store.fetch(path) { fail("testing: no slot for #{path}") }
    blk.call(res)
  end

  def reconnect(host, port)
    @recs << [host, port]
  end

  def send_data(data)
    # do nothing
  end
end

class ReconnectTest < Test::Unit::TestCase

  Walk  = 0
  Watch = 1

  attr_reader :c

  def setup
    @c = RecConn.new
  end

  def reply(to, path, value)
    res = Fraggle::Response.new
    res.tag   = to
    res.flags = Fraggle::Response::Flag::VALID
    res.path  = path
    res.value = value
    res.validate!

    c.receive_response(res)
  end

  def set(path, value)
    res = Fraggle::Response.new
    res.tag   = 123
    res.flags = Fraggle::Response::Flag::VALID
    res.value = value
    res.validate!

    c.store[path] = res
  end

  def test_ignore_current
    assert_equal Hash.new, c.doozers

    set "/doozer/info/ABC/public-addr", "1:1"
    reply(Walk, "/doozer/slot/1", "ABC")

    assert_equal Hash.new, c.doozers
  end

  def test_add_other_slots_at_start
    set "/doozer/info/DEF/public-addr", "2:2"
    set "/doozer/info/GHI/public-addr", "3:3"
    reply(Walk, "/doozer/slot/2", "DEF")
    reply(Walk, "/doozer/slot/3", "GHI")

    exp = {
      "/doozer/slot/2" => "2:2",
      "/doozer/slot/3" => "3:3"
    }

    assert_equal exp, c.doozers
  end

  def test_add_new_slots_as_they_come
    set "/doozer/info/DEF/public-addr", "2:2"
    set "/doozer/info/GHI/public-addr", "3:3"
    reply(Watch, "/doozer/slot/2", "DEF")
    reply(Watch, "/doozer/slot/3", "GHI")

    exp = {
      "/doozer/slot/2" => "2:2",
      "/doozer/slot/3" => "3:3"
    }

    assert_equal exp, c.doozers
  end

  def test_del_slots_if_they_emptied
    set "/doozer/info/DEF/public-addr", "2:2"
    set "/doozer/info/GHI/public-addr", "3:3"
    reply(Walk, "/doozer/slot/2", "DEF")
    reply(Walk, "/doozer/slot/3", "GHI")

    # Del
    reply(Watch, "/doozer/slot/3", "")

    exp = {
      "/doozer/slot/2" => "2:2"
    }

    assert_equal exp, c.doozers
  end

  def test_raise_error_if_given_by_server
    res = Fraggle::Response.new
    res.tag        = Walk
    res.flags      = Fraggle::Response::Flag::VALID
    res.err_code   = Fraggle::Response::Err::OTHER
    res.err_detail = "invalid glob"

    assert_raises Fraggle::AssemblyError do
      c.receive_response(res)
    end
  end

  def test_out_of_doozers
    assert_raises Fraggle::AssemblyError do
      c.unbind
    end
  end

  def test_first_reconnect_success
    set "/doozer/info/DEF/public-addr", "2:2"
    set "/doozer/info/GHI/public-addr", "3:3"
    reply(Walk, "/doozer/slot/2", "DEF")
    reply(Walk, "/doozer/slot/3", "GHI")

    c.unbind
    assert_equal 1, c.recs.length

    # The order in which the client try is non-detrministic because we're
    # shifting off a Hash.
    assert ["2:2", "3:3"].include?(c.addr)
  end

  def test_second_reconnect_success
    set "/doozer/info/DEF/public-addr", "2:2"
    set "/doozer/info/GHI/public-addr", "3:3"
    reply(Walk, "/doozer/slot/2", "DEF")
    reply(Walk, "/doozer/slot/3", "GHI")

    c.unbind
    c.unbind
    assert_equal 2, c.recs.length

    # The order in which the client try is non-detrministic because we're
    # shifting off a Hash.
    assert ["2:2", "3:3"].include?(c.addr)
  end

  def test_all_recconcts_fail
    set "/doozer/info/DEF/public-addr", "2:2"
    set "/doozer/info/GHI/public-addr", "3:3"
    reply(Walk, "/doozer/slot/2", "DEF")
    reply(Walk, "/doozer/slot/3", "GHI")

    c.unbind
    c.unbind

    assert_raises Fraggle::AssemblyError do
      c.unbind
    end
  end

end
