require 'test/unit'
require 'fraggle/connection'

class TestConn
  include Fraggle::Connection

  attr_reader :sent, :received
  attr_writer :error

  def initialize(addr, addrs=[])
    super(addr, addrs)
    @sent = []
    @received = []
  end

  def send_request(req)
    @sent << super(req)
    req
  end

  def receive_response(res)
    @received << res
    super(res)
  end

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

class Test::Unit::TestCase

  V = Fraggle::Request::Verb
  F = Fraggle::Response
  E = Fraggle::Response::Err

  Log = Struct.new(:valid, :error, :done)

  def request(verb, attrs={})
    log = Log.new([], [], [])
    req = Fraggle::Request.new(attrs.merge(:verb => verb))
    req.valid do |e|
      log.valid << e
    end
    req.done do
      log.done << req
    end
    req.error do |e|
      log.error << e
    end
    [req, log]
  end

  def reply(tag, attrs={})
    attrs[:flags] ||= 0
    attrs[:flags] |= F::VALID
    Fraggle::Response.new(attrs.merge(:tag => tag))
  end

  def reply!(tag, attrs={})
    attrs[:flags] = F::DONE
    reply(tag, attrs)
  end

end
