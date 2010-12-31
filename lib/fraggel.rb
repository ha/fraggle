require 'eventmachine'
require 'fraggel/decoder'
require 'fraggel/encoder'
require 'fraggel/responder'

module Fraggel
  include Encoder

  # Flags
  Valid = 1
  Done  = 2

  # Cas
  Dir     = "dir"
  Missing = "0"
  Clobber = ""

  # Create an unique object to test for
  # set or not-set
  None  = Object.new

  module Cas
    def dir?
      self == Dir
    end
  end

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

  def receive_response(response)
    opid, flags, value = response

    if blk = @callbacks[opid]
      if (flags & Valid) > 0
        blk.call(value)
      end

      if (flags & Done) > 0
        blk.call(:done)
        @callbacks.delete(opid)
      end
    else
      # TODO: Log something?  Raise error?
    end
  end

  def call(verb, args=None, &blk)
    @opid += 1
    @callbacks[@opid] = blk

    request = [@opid, verb.to_s]
    if args != None
      request << args
    end

    encoded = encode(request)

    # TODO: Chunk with next_tick
    send_data(encoded)

    @opid
  end

  def get(path, snap_id=0, &blk)
    call :GET, [path, snap_id] do |res|
      case res
      when StandardError
        blk.call(nil, nil, res)
      when :done
        # Do nothing
      else
        # Add sugar to the CAS token
        res[1].extend Cas
        blk.call(*res)
      end
    end
  end

  def set(path, body, cas, &blk)
    call :SET, [path, body, cas] do |res|
      case res
      when StandardError
        blk.call(nil, res)
      when :done
        # Do nothing
      else
        res.extend Cas
        blk.call(res)
      end
    end
  end

end
