require 'fraggel'

class LiveTest < Test::Unit::TestCase
  def start(&blk)
    EM.run do
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
end
