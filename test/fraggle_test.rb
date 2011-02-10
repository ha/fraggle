require 'fraggle'

class FraggleTest < Test::Unit::TestCase
  def test_addrs_for
    uri   = "doozer:?ca=ec2-123:9999&ca=127.0.0.1:8888"
    addrs = Fraggle.addrs_for(uri)
    assert_equal ["ec2-123:9999", "127.0.0.1:8888"], addrs
  end

  def test_addrs_for_error
    uri   = "doozer:?"
    assert_raises Fraggle::NoAddrs do
      Fraggle.addrs_for(uri)
    end
  end
end
