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

  def send_request(req, blk)
    @sent << super(req, blk)
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

  class Log
    attr_reader :valid

    def initialize
      @valid = []
    end

    def call(e)
      @valid << e
    end

    def to_proc
      me = self
      Proc.new {|e| me.call(e) }
    end
  end

  def request(verb, attrs={})
    logable(Fraggle::Request.new(attrs.merge(:verb => verb)))
  end

  def logable(req)
    log = Log.new
    req.valid(&log)
    [req, log]
  end

  def reply(tag, attrs={})
    Fraggle::Response.new(attrs.merge(:tag => tag))
  end

end
