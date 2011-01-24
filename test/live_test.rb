require 'fraggel'

class LiveTest < Test::Unit::TestCase
  def start(timeout=1, &blk)
    EM.run do
      if timeout > 0
        EM.add_timer(timeout) { fail "Test timeout!" }
      end

      blk.call(Fraggel.connect)
    end
  end

  def stop
    EM.stop
  end

  def test_get
    start do |c|
      c.get "/ping" do |e|
        assert e.cas > 0
        assert_equal "pong", e.value
        stop
      end
    end
  end

  def test_set
    start do |c|
      c.set "/foo", "bar", :clobber do |e|
        assert_nil e.err_code
        assert     e.cas > 0
        assert_nil e.value
        stop
      end
    end
  end
end
