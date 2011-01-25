require 'beefcake'
require 'eventmachine'
require 'fraggle/proto'

module Fraggle

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

    # Err sugar
    def ok?           ; err_code == nil               ; end
    def other?        ; err_code == Err::OTHER        ; end
    def tag_in_use?   ; err_code == Err::TAG_IN_USE   ; end
    def unknown_verb? ; err_code == Err::UNKNOWN_VERB ; end
    def redirect?     ; err_code == Err::REDIRECT     ; end
    def invalid_snap? ; err_code == Err::INVALID_SNAP ; end
    def mismatch?     ; err_code == Err::CAS_MISMATCH ; end
    def notdir?       ; err_code == Err::NOTDIR       ; end
    def dir?          ; err_code == Err::ISDIR        ; end

    # CAS sugar
    def missing?  ; cas ==  0 ; end
    def clobber?  ; cas == -1 ; end
    def dir?      ; cas == -2 ; end
    def dummy?    ; cas == -3 ; end
  end


  class AssemblyError < StandardError
  end


  def self.connect(addr="127.0.0.1:8046", opts={})
    # TODO: take a magnet link instead
    host, port = addr.split(":")
    EM.connect(host, port, self, addr, opts)
  end

  attr_reader :doozers, :addr, :opts

  def initialize(addr, opts)
    opts[:assemble] = opts.fetch(:assemble, true)

    # TODO: take a magnet link and load into @doozers
    @addr    = addr
    @opts    = opts
    @doozers = {}
  end

  ##
  # Collect all cluster information for the event of a disconnect from the
  # server; At which point we will want to attempt a connecting to them one by
  # one until we have a connection or run out of options.
  def assemble
    return if ! opts[:assemble]

    blk = Proc.new do |we|
      if ! we.ok?
        raise AssemblyError, we.err_detail
      end

      if we.value == ""
        doozers.delete(we.path)
      else
        get "/doozer/info/#{we.value}/public-addr" do |e|
          next if e.value == addr
          doozers[we.path] = e.value
        end
      end
    end

    watch "/doozer/slot/*", &blk
    walk  "/doozer/slot/*", &blk
  end

  ##
  # Attempts to connect to another doozer when a connection is lost
  def unbind
    return if ! opts[:assemble]

    _, @addr = doozers.shift
    if ! @addr
      raise AssemblyError, "All known doozers are down"
    end

    host, port = @addr.split(":")
    reconnect(host, port)
  end




  ##
  # Session generation
  def gen_key(name, size=16)
    nibbles = "0123456789abcdef"
    "#{name}." + (0...size).map { nibbles[rand(nibbles.length)].chr }.join
  end

  def session(name="fraggle", &blk)
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
      :cas => casify(cas),
      :path => id.to_s,
      &blk
    )
  end

  def post_init
    @buf = ""
    @tag = 0
    @cbx = {}
    @len = nil

    assemble
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
      :cas  => casify(cas),
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
