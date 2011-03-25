require 'fraggle/connection'

class FraggleTransactionTest < Test::Unit::TestCase
  V = Fraggle::Request::Verb
  F = Fraggle::Response
  E = Fraggle::Response::Err

  class TestConn
    include Fraggle::Connection

    def send_data(_)
    end
  end

  attr_reader :cn, :tmp, :valid, :done, :error


  def nop(attrs={})
    r(V::NOP, attrs)
  end

  def r(verb, attrs={})
    req = Fraggle::Request.new(attrs)
    req.verb = verb

    req.valid do |e|
      @valid << e
    end

    req.error do |e|
      @error << e
    end

    req.done do
      @done << true
    end
  end

  def setup
    @cn    = TestConn.new
    @valid = []
    @done  = []
    @error = []
  end

  def test_tagging
    req = nop
    assert_equal 0, cn.send_request(req).tag
    req = nop
    assert_equal 1, cn.send_request(req).tag
    req = nop
    assert_equal 2, cn.send_request(req).tag
  end

  def test_valid
    req = cn.send_request(nop)

    res = Fraggle::Response.new :tag => req.tag, :flags => F::VALID
    cn.receive_response(res)

    assert_equal [res], valid
    assert_equal [], done
  end

  def test_done
    req = cn.send_request(nop)

    res = Fraggle::Response.new :tag => req.tag, :flags => F::DONE
    cn.receive_response(res)

    assert_equal [], valid
    assert_equal [true], done
  end

  def test_valid_and_done
    req = cn.send_request(nop)

    res = Fraggle::Response.new :tag => req.tag, :flags => F::VALID|F::DONE
    cn.receive_response(res)

    assert_equal [res], valid
    assert_equal [true], done
  end


  def test_error
    req = cn.send_request(nop)

    res = Fraggle::Response.new(
      :tag => req.tag,
      :flags => F::VALID|F::DONE,
      :err_code => E::OTHER
    )

    cn.receive_response(res)

    assert_equal [], valid
    assert_equal [], done
    assert_equal [res], error
  end

  def test_invalid_tag
    res = Fraggle::Response.new(
      :tag => 0,
      :flags => F::VALID|F::DONE,
      :err_code => E::OTHER
    )

    assert_nothing_raised do
      cn.receive_response(res)
    end
  end

  def test_done_deletes_callback
    req = cn.send_request(nop)

    res = Fraggle::Response.new(:tag => req.tag, :flags => F::VALID|F::DONE)
    cn.receive_response(res)

    # This should be ignored
    cn.receive_response(res)

    assert_equal [res], valid
  end

  def test_error_with_done_deletes_callback
    req = cn.send_request(nop)

    res = Fraggle::Response.new(
      :tag => req.tag,
      :flags => F::VALID|F::DONE,
      :err_code => E::OTHER
    )

    cn.receive_response(res)

    # This should be ignored
    cn.receive_response(res)

    assert_equal [res], error
  end

  def test_cannot_reuse_sent_request
    req = cn.send_request(nop)

    assert_raises Fraggle::Connection::SendError do
      cn.send_request(req)
    end
  end

  def test_cancel
    req = cn.send_request(nop)
    can = req.cancel

    canx = Fraggle::Response.new(:tag => can.tag, :flags => F::VALID|F::DONE)
    cn.receive_response(canx)
  end

  def test_cannot_cancel_more_than_once
    req = cn.send_request(nop)
    req.cancel

    assert_raises Fraggle::Connection::SendError do
      req.cancel
    end
  end

  def test_cancel_emits_done
    req = cn.send_request(nop)
    can = req.cancel

    canx = Fraggle::Response.new(:tag => can.tag, :flags => F::VALID|F::DONE)
    cn.receive_response(canx)

    assert_equal [true], done
  end

end
