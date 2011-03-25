require 'fraggle/connection'

class FraggleTransactionTest < Test::Unit::TestCase
  V = Fraggle::Request::Verb
  F = Fraggle::Response
  E = Fraggle::Response::Err

  class TestConn
    include Fraggle::Connection

    attr_accessor :error

    def error?
      !!@error
    end

    def send_data(_)
    end

    def close_connection
      @error = true
      unbind
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
    @cn    = TestConn.new("127.0.0.1:0")
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

  def test_diconnected
    req = [
      cn.send_request(nop),
      cn.send_request(nop),
      cn.send_request(nop),
    ]

    cn.unbind

    assert_equal req.length, error.length

    error.each_with_index do |err, i|
      err = error[i]
      assert_instance_of Fraggle::Connection::Disconnected, err
      assert_equal req[i], err.req
    end
  end

  def test_send_request_in_error_state
    cn.error = true

    req = cn.send_request(nop)
    assert_equal nil, req.tag

    assert_instance_of Fraggle::Connection::Disconnected, error.first
  end

  def test_liveness
    live = cn.post_init

    def cn.timer(_, &blk)
      blk.call
    end

    res = Fraggle::Response.new(:tag => live.tag, :rev => 1, :flags => F::VALID|F::DONE)
    cn.receive_response(res)
    assert ! cn.error?

    # Connections reuse tags and we're only responding to one request in this
    # test, so we know the next rev will use the previous tag
    res = Fraggle::Response.new(:tag => live.tag, :rev => 2, :flags => F::VALID|F::DONE)
    cn.receive_response(res)
    assert ! cn.error?
  end

  def test_not_alive
    live = cn.post_init

    def cn.timer(_, &blk)
      blk.call
    end

    res = Fraggle::Response.new(:tag => live.tag, :rev => 1, :flags => F::VALID|F::DONE)
    cn.receive_response(res)
    assert ! cn.error?

    cn.receive_response(res)
    assert cn.error?
  end

end
