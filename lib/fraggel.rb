require 'beefcake'
require 'eventmachine'
require 'fraggel/proto'

module Fraggel

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

    # TODO: check blk.nil?
    if res.valid?
      blk.call(res, false)
    end

    if res.done?
      if blk.arity == 2
        blk.call(nil, true)
      end
      @cbx.delete(res.tag)
    end
  end

  def get(path, sid=0, &blk)
  end

  def call(verb, attrs={}, &blk)
    attrs[:verb] = verb
    attrs[:tag]  = tag = @tag += 1
    @cbx[tag]    = blk

    send_request(Request.new(attrs))
  end

  def send_request(req)
    buf = req.encode

    send_data([buf.length].pack("N"))
    send_data(buf)
  end

end
