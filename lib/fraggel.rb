require 'eventmachine'
require 'fraggel/decoder'
require 'fraggel/encoder'
require 'fraggel/responder'

module Fraggel
  include Encoder

  Closed = 1
  Last   = 2

  Chunk  = 1024

  def self.connect(port, host="127.0.0.1")
    EM.connect(host, port, self)
  end

  def post_init
    @callbacks = {}
    @opid      = 0

    @responder = Responder.new do |value|
      receive_response(value)
    end

    @decoder   = Decoder.new do |name, value|
      @responder.receive_event(name, value)
    end
  end

  def receive_data(data)
    @decoder.receive_data(data)
  end

  def last?(flags)
    flags | Last > 0
  end

  def closed?(flags)
    flags | Closed > 0
  end

  def receive_response(response)
    opid, flags, value = response

    if blk = @callbacks[opid]
      if last?(flags) || closed?(flags)
        @callbacks.delete(opid)
      end

      if last?(flags)
        blk.call(value)
      end
    else
      # TODO: Log something?  Raise error?
    end
  end

  def call(verb, args, &blk)
    @opid += 1
    @callbacks[@opid] = blk
    request = [@opid, verb.to_s, args]
    encoded = encode(request)
    # TODO: Chunk with next_tick
    send_data(encoded)
  end

  def set(path, body, cas, &blk)
    call :SET, [path, body, casify(cas)] do |response|
      if response === StandardError
        blk.call(cas, response)
      else
        blk.call(cas, nil)
      end
    end
  end

  def casify(cas)
    case cas
    when :missing: "0"
    when :clobber: ""
    else cas
    end
  end

end
