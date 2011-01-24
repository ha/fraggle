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
        assert e.ok?, e.err_detail
        assert e.cas > 0
        assert_equal "pong", e.value
        stop
      end
    end
  end

  def test_set
    start do |c|
      c.set "/test-set", "a", :clobber do |ea|
        assert ea.ok?, ea.err_detail
        assert ea.cas > 0
        assert_nil ea.value

        c.get "/test-set" do |eb|
          assert eb.ok?, eb.err_detail
          assert_equal "a", eb.value
          stop
        end
      end
    end
  end

  def test_error
    start do |c|
      c.set "/test-error", "a", :clobber do |ea|
        assert ! ea.mismatch?
        assert ea.ok?, ea.err_detail
        c.set "/test-error", "b", :missing do |eb|
          assert eb.mismatch?, eb.err_detail
          stop
        end
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
        EM.next_tick { c.set("/test-watch", "something", :clobber) }
      end
    end
  end
end
