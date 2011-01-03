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
    call :SET, [path, body, casify(cas)] do |res|
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

  def sett(path, i, cas, &blk)
    call :SETT, [path, i, casify(cas)] do |res|
      case res
      when StandardError
        blk.call(nil, nil, res)
      when :done
        # Do nothing
      else
        res[1].extend Cas
        blk.call(*res)
      end
    end
  end

  def close(opid, &blk)
    call :CLOSE, opid do |res|
      case res
      when StandardError
        blk.call(res)
      when :done
        # Do nothing
      else
        blk.call(nil)
      end
    end
  end

  def del(path, cas, &blk)
    call :DEL, [path, cas] do |res|
      case res
      when StandardError
        blk.call(res)
      when :done
        # Do nothing
      else
        blk.call(nil)
      end
    end
  end

  def noop(&blk)
    call :NOOP do |res|
      case res
      when StandardError
        blk.call(res)
      when :done
        # Do nothing
      else
        blk.call(nil)
      end
    end
  end

  def snap(&blk)
    call :SNAP do |res|
      case res
      when StandardError
        blk.call(nil, res)
      when :done
        # Do nothing
      else
        blk.call(res, nil)
      end
    end
  end

  def delsnap(&blk)
    call :DELSNAP do |res|
      case res
      when StandardError
        blk.call(nil, res)
      when :done
        # Do nothing
      else
        blk.call(res, nil)
      end
    end
  end

  def walk(glob, sid=0, &blk)
    call :WALK, [glob, sid] do |res|
      case res
      when StandardError
        blk.call(nil, nil, nil, res)
      when :done
        # Do nothing
      else
        res[2].extend Cas
        blk.call(*res)
      end
    end
  end

  private

    def casify(cas)
      case cas
      when :missing: "0"
      when :clobber: ""
      else cas
      end
    end

end
