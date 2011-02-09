require 'fraggle/client'
require 'fraggle/protocol'
require 'fraggle/response'
require 'fraggle/test'

class FraggleProtocolTest < Test::Unit::TestCase
  include Fraggle::Test

  class TestConn < Array
    include Fraggle::Protocol
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
    req = Fraggle::Response.new :tag => 0, :verb => V::NOOP, :flags => F::VALID
    cn.receive_data(encode(req))

    assert_equal [req], cn
  end

  def test_multiple_single
    a = Fraggle::Response.new :tag => 0, :verb => V::NOOP, :flags => F::VALID
    b = Fraggle::Response.new :tag => 1, :verb => V::NOOP, :flags => F::VALID
    cn.receive_data(encode(a) + encode(b))

    assert_equal [a, b], cn
  end

  def test_multiple_double
    a = Fraggle::Response.new :tag => 0, :verb => V::NOOP, :flags => F::VALID
    b = Fraggle::Response.new :tag => 1, :verb => V::NOOP, :flags => F::VALID
    cn.receive_data(encode(a))
    cn.receive_data(encode(b))

    assert_equal [a, b], cn
  end

  def test_small_chunks
    req = Fraggle::Response.new :tag => 0, :verb => V::NOOP, :flags => F::VALID

    bytes = encode(req) * 3
    len   = bytes.length

    0.step(len, 1) do |i|
      data = bytes.slice!(0, i)
      cn.receive_data(data)
    end

    assert_equal [req, req, req], cn
  end

  def test_big_chunks
    req = Fraggle::Response.new :tag => 0, :verb => V::NOOP, :flags => F::VALID

    bytes = encode(req) * 3
    len   = bytes.length

    0.step(len, len/2) do |i|
      data = bytes.slice!(0, i)
      cn.receive_data(data)
    end

    assert_equal [req, req, req], cn
  end

  def test_send_request
    c = Class.new do
      include Fraggle::Client

      attr_reader :data

      def initialize
        @data = ""
        super("doozer:?ca=127.0.0.1:8046")
      end

      def send_data(data)
        @data << data
      end
    end.new

    req   = c.noop
    bytes = req.encode
    head  = [bytes.length].pack("N")

    assert_equal head+bytes, c.data
  end

end
