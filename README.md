# Fraggle
**An EventMachine based Doozer client**

# This README is out of sync with the 0.4.0 gem.  There
# will be an updated release soon.

## Install

    $ gem install fraggle

## Use

    require 'rubygems'
    require 'eventmachine'
    require 'fraggle'

    EM.start do
      # Fraggle keeps track of this addr plus all others it finds once
      # connected.  In the event of a lost connection, fraggle will attempt
      # other doozers until one accepts or it runs out of options; An
      # AssemlyError will be raised if that later happens.
      c = Fraggle.connect "doozerd://127.0.0.1:8046"

      req = c.get(nil, "/foo") do |e|
        e.value   # => "bar"
        e.cas     # => "123"
        e.dir?    # => false
        e.notdir? # => true
      end

      req.error do |e|
        e.err_code   # => nil
        e.err_detail # => nil
      end

      watch = c.watch(nil, "/foo") do |e|
        # The event has:
        # ------------------------
        e.err_code   # => nil
        e.err_detail # => nil
        e.path       # => "/foo"
        e.value      # => "bar"
        e.cas        # => "123"
        e.set?       # => true
        e.del?       # => false

        do_something_with(e)

        # Phoney check for example
        if can_stop_watching?(path)
          watch.cancel
        end
      end

      ## Setting a key (this will trigger the watch above)
      req = c.set(0, "/foo", "zomg!") do |e|
        case true
        when e.mismatch? # CAS mis-match
          # retry if we must
        when e.ok?
          e.cas # => "123"
        else
          raise e.err_detail
        end
      end.error do
        # This is the default behavior for fraggle.
        # I'm showing this to bring attention to the use of the
        # error callback.
        raise e.err_detail
      end

      # Knowning when a command is done is useful in some cases.
      # Use the `done` callback for those situations.
      ents = []
      req = c.getdir("/test") do |e|
        ents << e
      end.done do
        p ents
      end

    end


## Dev

**Clone**
    $ git clone http://github.com/bmizerany/fraggle.git

**Test**
    $ gem install turn
    $ turn
