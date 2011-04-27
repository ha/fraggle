require 'test/unit'
require 'fraggle/connection'

class TestConn
  include Fraggle::Connection

  attr_reader :sent, :received
  attr_writer :err

  def initialize(addr)
    super(addr)
    @sent = []
    @received = []
    @ticks = []
  end

  def send_request(req)
    @sent << super(req)
    req
  end

  def receive_response(res)
    @received << res
    super(res)
  end

  def send_data(_)
  end

  def close_connection
    unbind
  end

  # Mimic EMs next_tick
  def next_tick(&blk)
    @ticks << blk
  end

  # Mimic a turn in the reactor
  def tick!
    @ticks.each {|blk| blk.call }
    @ticks.clear
  end

end

class Test::Unit::TestCase

  V = Fraggle::Request::Verb
  F = Fraggle::Response
  E = Fraggle::Response::Err

  Log = Struct.new(:valid, :error, :done)

  def request(verb, attrs={})
    logable(Fraggle::Request.new(attrs.merge(:verb => verb)))
  end

  def logable(req)
    log = Log.new([], [], [])
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
    Fraggle::Response.new(attrs.merge(:tag => tag))
  end

end
