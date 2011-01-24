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
        assert_nil   e.err_code
        assert       e.cas > 0
        assert_equal "pong", e.value
        stop
      end
    end
  end

  def test_set
    start do |c|
      c.set "/foo", "bar", :clobber do |e|
        assert e.ok?, e.err_detail
        assert     e.cas > 0
        assert_nil e.value
        c.get "/foo" do |e|
          assert e.ok?, e.err_detail
          assert_equal "bar", e.value
          stop
        end
      end
    end
  end

  def test_error
    start do |c|
      c.set "/ping", "dummy", 999999 do |e|
        assert e.mismatch?
      end

      c.set "/foo", "bar", :clobber do |e|
        assert ! e.mismatch?
        stop
      end
    end
  end

  def test_watch
    start do |c|
      count = 0
      c.watch("/**") do |e|
        assert e.ok?, e.err_detail

        count += 1
        if count == 9
          stop
        end
      end

      10.times do
        EM.next_tick { c.set("/foo", "bar", :clobber) }
      end
    end
  end
end
