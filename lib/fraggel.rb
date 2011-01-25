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

  def gen_key(name, size=16)
    nibbles = "0123456789abcdef"
    "#{name}." + (0...size).map { nibbles[rand(nibbles.length)].chr }.join
  end

  def session(name="fraggel", &blk)
    raise ArgumentError, "no block given" if ! blk

    id = gen_key(name)

    fun = lambda do |e|
      raise e.err_detail if ! e.ok?
      checkin(e.cas, id, &fun)
    end

    established = lambda do |e|
      case true
      when e.mismatch?
        id = gen_key(name)
        checkin(0, id, &established)
      when ! e.ok?
        raise e.err_detail
      else
        blk.call
        checkin(e.cas, id, &fun)
      end
    end

    checkin(0, id, &established)
  end

  def checkin(cas, id, &blk)
    call(
      Request::Verb::CHECKIN,
      :cas => cas,
      :path => id.to_s,
      &blk
    )
  end

  def post_init
    @buf = ""
    @tag = 0
    @cbx = {}
    @len = nil
  end

  def receive_data(data)
    @buf << data

    got = true
    while got
      got = false

      if @len.nil? && @buf.length >= 4
        @len = @buf.slice!(0, 4).unpack("N").first
      end

      if @len && @buf.length >= @len
        bytes = @buf.slice!(0, @len)
        res   = Response.decode(bytes)
        receive_response(res)
        @len = nil
        got = true
      end
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
      :value => body,
      :cas => casify(cas),
      &blk
    )
  end

  def del(path, cas, &blk)
    call(
      Request::Verb::DEL,
      :path => path,
      :cas  => cas,
      &blk
    )
  end

  def watch(glob, &blk)
    call(
      Request::Verb::WATCH,
      :path => glob,
      &blk
    )
  end

  def walk(glob, &blk)
    call(
      Request::Verb::WALK,
      :path => glob,
      &blk
    )
  end

  def snap(&blk)
    call(
      Request::Verb::SNAP,
      &blk
    )
  end

  def delsnap(id, &blk)
    call(
      Request::Verb::DELSNAP,
      :id => id,
      &blk
    )
  end

  def noop(&blk)
    call(
      Request::Verb::NOOP,
      &blk
    )
  end

  def cancel(tag)
    blk = lambda do |e|
      if e.ok?
        if blk = @cbx.delete(tag)
          blk.call(nil, true)
        end
      end
    end

    call(
      Request::Verb::CANCEL,
      :id => tag,
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
