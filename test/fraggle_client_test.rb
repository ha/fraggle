require 'fraggle/client'
require 'fraggle/response'
require 'fraggle/test'

class FraggleClientTest < Test::Unit::TestCase
  include Fraggle::Test

  attr_reader :c, :blk

  def setup
    @c   = TestClient.new
    @blk = Blk.new
  end

  def test_send_recv
    req = c.send(Fraggle::Request.new, &blk)

    assert_sent req.tag
    assert_recv reply(req.tag)
  end

  def test_valid
    req = c.send(Fraggle::Request.new, &blk)

    reply(req.tag)
    reply(req.tag)
    reply(req.tag)

    assert_equal 3, blk.length
  end

  def test_done
    req = c.send(Fraggle::Request.new)
    req.done(&blk)

    reply!(req.tag)

    assert_equal 1, blk.length

    req.valid(&blk)

    reply(req.tag)
    reply(req.tag)
    reply(req.tag)

    assert_equal 1, blk.length
  end

  def test_default_error
    req = c.send(Fraggle::Request.new)

    assert_raises Fraggle::Client::Error do
      reply(req.tag, :err_code => E::OTHER, :err_detail => "boom!")
    end

    assert_nothing_raised do
      reply(req.tag, :err_code => E::OTHER, :err_detail => "boom!")
    end
  end

  def test_error
    req = c.send(Fraggle::Request.new)
    req.error(&blk)

    reply(req.tag, :err_code => E::OTHER, :err_detail => "boom!")
    reply(req.tag, :err_code => E::OTHER, :err_detail => "boom!")

    assert_equal 1, blk.length
  end

  def test_tagging
    t = Fraggle::Client::MinTag

    assert_equal t+0, c.noop.tag
    assert_equal t+1, c.noop.tag
    assert_equal t+2, c.noop.tag
    assert_equal t+3, c.noop.tag
    assert_equal t+4, c.noop.tag
  end

  # CHECKIN cas, path         => cas
  def test_checkin
    req = c.checkin("abc123", 123, &blk)

    assert_sent(req.tag, :verb => V::CHECKIN, :path => "abc123", :cas => 123)
    assert_recv(reply(req.tag, :cas => 123))
  end

  # GET     path, id         => cas, value
  def test_get
    req = c.get(0, "/ping", &blk)

    assert_sent req.tag, :verb => V::GET, :path => "/ping"
    assert_recv reply(req.tag, :cas => 123, :value => "pong")
  end

  # STAT     path, id         => cas, len
  def test_stat
    req = c.stat(0, "/ping", &blk)

    assert_sent req.tag, :verb => V::STAT, :path => "/ping"
    assert_recv reply(req.tag, :cas => 123, :len => 4)
  end

  # GETDIR     id, path, offset, limit         => {cas, value}+
  def test_getdir
    req = c.getdir(0, "/test", 0, 0, &blk)

    assert_sent req.tag, :verb => V::GETDIR, :path => "/test"
    assert_recv reply(req.tag, :cas => 123, :value => "a")

    req = c.getdir(0, "/test", 1, 2, &blk)

    assert_sent req.tag, :verb => V::GETDIR, :path => "/test", :offset => 1, :limit => 2
    assert_recv reply(req.tag, :cas => 123, :value => "b")
  end

  # SET     cas, path, value => cas
  def test_set
    req = c.set("/foo", "bar", 123, &blk)

    assert_sent(req.tag, :verb => V::SET,  :cas => 123, :path => "/foo", :value => "bar")
    assert_recv(reply(req.tag, :cas => 123))
  end

  # DEL     cas, path        => {}
  def test_del
    req = c.del("/foo", 123, &blk)

    assert_sent(req.tag, :verb => V::DEL, :cas => 123, :path => "/foo")
    assert_recv(reply(req.tag))
  end

  # WALK     path, id         => {cas, path, value}+
  def test_walk
    req = c.walk(0, "/foo/*", &blk)

    assert_respond_to req, :cancel

    assert_sent(req.tag, :verb => V::WALK, :path => "/foo/*")
    assert_recv(reply(req.tag, :cas => 123, :path => "/foo/a", :value => "1"))
    assert_recv(reply(req.tag, :cas => 456, :path => "/foo/b", :value => "2"))
    assert_recv(reply(req.tag, :cas => 789, :path => "/foo/c", :value => "3"))
  end

  # WATCH    path             => {cas, path, value}+
  def test_watch
    req = c.watch("/foo/*", &blk)

    assert_respond_to req, :cancel

    assert_sent(req.tag, :verb => V::WATCH, :path => "/foo/*")
    assert_recv(reply(req.tag, :cas => 123, :path => "/foo/a", :value => "1"))
    assert_recv(reply(req.tag, :cas => 456, :path => "/foo/b", :value => "2"))
    assert_recv(reply(req.tag, :cas => 789, :path => "/foo/c", :value => "3"))
  end

  # SNAP     {}               => id
  def test_snap
    req = c.snap(&blk)

    assert_sent(req.tag, :verb => V::SNAP)
    assert_recv(reply(req.tag, :id => 1))
  end

  # DELSNAP  id               => {}
  def test_delsnap
    req = c.delsnap(1, &blk)

    assert_sent(req.tag, :verb => V::DELSNAP, :id => 1)
    assert_recv(reply(req.tag))
  end

  # NOOP     {}               => {}
  def test_noop
    req = c.noop(&blk)

    assert_sent(req.tag, :verb => V::NOOP)
    assert_recv(reply(req.tag))
  end

  # CANCEL   id               => {}
  def test_cancel
    nop = c.noop(&blk)
    req = c.__cancel__(nop, &blk)

    assert_sent(req.tag, :verb => V::CANCEL, :id => nop.tag)
    assert_recv(reply(req.tag))
  end

  def test_cancelable
    can = c.cancelable(Fraggle::Request.new(:tag => 123))

    assert ! can.canceled?

    req = can.cancel

    assert can.canceled?
    assert_equal 1, c.length
    assert_sent req.tag, :verb => V::CANCEL, :id => can.tag

    # A few more for good measure
    can.cancel
    can.cancel

    # Ensure we haven't called cancel on the same tag more than once.
    assert_equal 1, c.length
  end

  def test_cancel_does_not_prematurely_remove_callback
    x = c.watch("/foo/*", &blk)
    y = x.cancel

    assert_not_equal x.object_id, y.object_id
    assert_not_equal x.tag, y.tag
  end

  def test_cancel_discards_further_replies
    x = c.watch("/foo/*", &blk)
    x.cancel

    reply!(x.tag)

    # The cancel happened before the reply was received by the reactor.  Any
    # remaining data from the server should be discarded.
    assert_equal 0, blk.length
  end

  def test_tag_pending_cancel_is_not_useable
    x = c.watch("/foo/*", &blk)
    y = x.cancel

    # Force a reset of tag so that `send` will attempt
    # to reuse the pending cancels tag.
    c.instance_eval { @tag = x.tag }

    z = c.noop

    assert_not_equal x.tag, z.tag
    assert_not_equal y.tag, z.tag
  end

  def test_reuse_canceled_tag
    x = c.watch("/foo/*", &blk)
    y = x.cancel

    reply!(y.tag)

    z = c.noop

    assert_equal x.tag, z.tag
  end

  # These are planned for future doozer versions
  #
  # ESET     cas, path        => {}
  # GETDIR   path             => {cas, value}+
  # MONITOR  path             => {cas, path, value}+
  # SYNCPATH path             => cas, value

end
