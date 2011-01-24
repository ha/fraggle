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

    def ok?       ; err_code == nil ; end
    def mismatch? ; err_code == Err::CAS_MISMATCH ; end
  end

  def self.connect(port=8046, host="127.0.0.1")
    # TODO: take a magnet link instead
    EM.connect(host, port, self)
  end

  def post_init
    @buf = ""
    @tag = 0
    @cbx = {}
    @len = nil
  end

  def receive_data(data)
    @buf << data

    if ! @len && @buf.length >= 4
      @len = @buf.slice!(0, 4).unpack("N").first
    end

    if @len && @buf.length >= @len
      bytes = @buf.slice!(0, @len)
      res   = Response.decode(bytes)
      receive_response(res)
      @len = nil
    end
  end

  def receive_response(res)
    blk = @cbx[res.tag]

    if blk && res.valid?
      if blk.arity == 2
        blk.call(res, false)
      else
        blk.call(res)
      end
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
    @cbx[@tag]   = blk

    send_request(Request.new(attrs))

    @tag
  end

  def send_request(req)
    buf = req.encode

    send_data([buf.length].pack("N"))
    send_data(buf)
  end



  ##
  # Sugar
  def get(path, sid=0, &blk)
    call(
      Request::Verb::GET,
      :path => path,
      :id => sid,
      &blk
    )
  end

  def set(path, body, cas, &blk)
    call(
      Request::Verb::SET,
      :path => path,
      :body => body,
      :cas => casify(cas),
      &blk
    )
  end

  def watch(glob, &blk)
    call(
      Request::Verb::WALK,
      :path => glob,
      &blk
    )
  end

  private

  def casify(cas)
    case cas
    when :missing then 0
    when :clobber then -1
    else cas
    end
  end

end
