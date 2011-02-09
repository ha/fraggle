require 'fraggle/test'
require 'fraggle/snap'

class FraggleSnapTest < Test::Unit::TestCase
  include Fraggle::Test

  attr_reader :c, :blk

  def setup
    cl   = TestClient.new("doozer://127.0.0.1:8046")
    @c   = Fraggle::Snap.new(1, cl)
    @blk = Blk.new
  end

  def test_get
    req = c.get("/ping", &blk)

    assert_sent req.tag, :verb => V::GET, :id => 1, :path => "/ping"
    assert_recv reply(req.tag)
  end

  def test_stat
    req = c.stat("/ping", &blk)

    assert_sent req.tag, :verb => V::STAT, :id => 1, :path => "/ping"
    assert_recv reply(req.tag)
  end

  def test_getdir
    req = c.getdir("/test", &blk)

    assert_sent req.tag, :verb => V::GETDIR, :path => "/test", :id => 1
    assert_recv reply(req.tag)

    req = c.getdir("/test", 1, 2, &blk)

    assert_sent req.tag, :verb => V::GETDIR, :path => "/test", :offset => 1, :limit => 2, :id => 1
    assert_recv reply(req.tag)
  end

  def test_walk
    req = c.walk("/letters/*", &blk)

    assert_sent req.tag, :verb => V::WALK, :id => 1, :path => "/letters/*"
    assert_recv reply(req.tag)
  end

  def test_other
    req = c.noop(&blk)

    assert_sent req.tag, :verb => V::NOOP
    assert_recv reply(req.tag)
  end

  def test_snap
    b = nil
    a = c.snap do |sn|
      b = sn.get("/ping")
    end

    reply(a.tag, :id => 99)

    assert_sent a.tag, :verb => V::SNAP
    assert_sent b.tag, :verb => V::GET, :id => 99, :path => "/ping"
  end

end
