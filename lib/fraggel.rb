require 'beefcake'
require 'eventmachine'
require 'fraggel/proto'

module Fraggel

  MaxInt32 = (1<<31)-1
  MinInt32 = -(1<<31)

  ##
  # Response extensions
  class Response
    module Flag
      VALID = 1
      DONE  = 2
    end

    def valid?
      (flags & Flag::VALID) > 0
    end

    def done?
      (flags & Flag::DONE) > 0
    end
  end

  def self.connect(port=8046, host="127.0.0.1")
    # TODO: take a magnet link instead
    EM.connect(host, port, self)
  end

  def post_init
    @buf = ""
    @tag = 0
    @cbx = {}
  end

  def receive_data(data)
    # TODO: stream
    res = Response.decode(data)
    receive_response(res)
  end

  def receive_response(res)
    blk = @cbx[res.tag]

    if res.valid?
      blk.call(res, false) if blk
    end

    if res.done?
      if blk && blk.arity == 2
        blk.call(nil, true)
      end
      @cbx.delete(res.tag)
    end
  end

  def call(verb, attrs={}, &blk)
    if @tag == MaxInt32
      @tag = MinInt32
    end

    while true
      break if ! @cbx.has_key?(@tag)
      @tag += 1
    end

    attrs[:verb] = verb
    attrs[:tag]  = @tag
    @cbx[tag]    = blk

    send_request(Request.new(attrs))

    @tag
  end

  def send_request(req)
    buf = req.encode

    send_data([buf.length].pack("N"))
    send_data(buf)
  end

end
