require 'fraggel'

class LiveTest < Test::Unit::TestCase
  def test_get
    EM.run do
      c = Fraggel.connect

      c.get "/ping" do |e|
        assert_equal "pong", e.value
        EM.stop
      end
    end
  end
end
