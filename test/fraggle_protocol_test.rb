require 'fraggle/connection'

class FraggleProtocolTest < Test::Unit::TestCase
  V = Fraggle::Request::Verb
  F = Fraggle::Request

  class TestConn < Array
    include Fraggle::Connection
    alias :receive_response :<<
  end

  attr_reader :cn

  def setup
    @cn  = TestConn.new
  end

  def encode(req)
    data = req.encode
    [data.length].pack("N") + data
  end

  def test_simple
    req = Fraggle::Response.new :tag => 0, :verb => V::NOP, :flags => F::VALID
    cn.receive_data(encode(req))

    assert_equal [req], cn
  end

  def test_multiple_single
    a = Fraggle::Response.new :tag => 0, :verb => V::NOP, :flags => F::VALID
    b = Fraggle::Response.new :tag => 1, :verb => V::NOP, :flags => F::VALID
    cn.receive_data(encode(a) + encode(b))

    assert_equal [a, b], cn
  end

  def test_multiple_double
    a = Fraggle::Response.new :tag => 0, :verb => V::NOP, :flags => F::VALID
    b = Fraggle::Response.new :tag => 1, :verb => V::NOP, :flags => F::VALID
    cn.receive_data(encode(a))
    cn.receive_data(encode(b))

    assert_equal [a, b], cn
  end

  def test_small_chunks
    req = Fraggle::Response.new :tag => 0, :verb => V::NOP, :flags => F::VALID

    bytes = encode(req) * 3
    len   = bytes.length

    0.step(len, 1) do |i|
      data = bytes.slice!(0, i)
      cn.receive_data(data)
    end

    assert_equal [req, req, req], cn
  end

  def test_big_chunks
    req = Fraggle::Response.new :tag => 0, :verb => V::NOP, :flags => F::VALID

    bytes = encode(req) * 3
    len   = bytes.length

    0.step(len, len/2) do |i|
      data = bytes.slice!(0, i)
      cn.receive_data(data)
    end

    assert_equal [req, req, req], cn
  end

  def test_send_request
    req   = Fraggle::Request.new :tag => 0, :verb => V::NOP
    bytes = req.encode
    head  = [bytes.length].pack("N")

    sent  = ""
    (class << cn ; self ; end).instance_eval do
      define_method(:send_data) do |data|
        sent << data
      end
    end

    cn.send_request(req)

    assert_equal head+bytes, sent
  end

end
