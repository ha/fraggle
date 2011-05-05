require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do
  # In the event of a lost connection, fraggle will attempt
  # other doozers until one accepts or it runs out of options; A NoAddrs
  # exception will be raised if that later happens.

  c = Fraggle.connect

  c.rev do |v|
    c.get(v, "/foo") do |e, err|
      if err
        err.code   # => nil
        err.detail # => nil
      else
        e.value    # => nil
        e.rev      # => 0
        e.missing? # => true
      end

      p [:get, e, err]
    end

    ## Obtain the current revision the store is at and watch from then on for
    ## any SET or DEL to /foo.
    c.wait(v, "/foo") do |e, err|
      # The event has:
      # ------------------------
      if err
        err.code   # => nil
        err.detail # => nil
      else
        e.path       # => "/foo"
        e.value      # => "zomg!"
        e.rev        # => 123
        e.set?       # => true
        e.del?       # => false
      end

      p [:wait, e, err]
    end
  end

  ## Setting a key (this will trigger the watch above)
  f = Proc.new do |e, err|
    p [:e, e, err]

    if err && err.disconnected?
      # Fraggle (for now) does not attempt a non-idempotent request.  This means
      # Fraggle will hand off the error to the user if there is a SET or DEL
      # with rev 0 (missing) and delete it during the time we may be
      # disconnected.
      #
      # In this scenario, there are no other clients that can exist that will
      # attempt to set this "lock" if it's missing then delete it.  It is safe
      # for us to resend the request if we were disconnected from the previous
      # server before a response.
      #
      # See High-Availability in the README for more information about this.
      #
      c.set(0, "/foo", "zomg!", &f)
      next
    end

    # Success!
    if err
      case err.code
      when Fraggle::REV_MISMATCH
        p :not_it
      when nil
        # Success!
        p [:it, e]
      else
        fail "something bad happened: " + e.inspect
      end
    end
  end

  c.set(0, "/foo", "zomg!", &f)
end
