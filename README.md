# Fraggle
**An EventMachine based Doozer client**

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
      c = Fraggle.connect "127.0.0.1:8046"

      c.get "/foo" do |e|
        if e.ok?
          e.value   # => "bar"
          e.cas     # => "123"
          e.dir?    # => false
          e.notdir? # => true
        end
      end

      watch = c.watch "/foo" do |e|
        # The event has:
        # ------------------------
        e.err_code   # => nil
        e.err_detail # => nil
        e.path       # => "/foo"
        e.value      # => "bar"
        e.cas        # => "123"
        e.dir?       # => false
        e.notdir?    # => true
        e.set?       # => true
        e.del?       # => false

        done_something_with(e)

        # Phoney check for example
        if can_stop_watching?(path)
          c.cancel(watch)
        end
      end

      ## Setting a key (this will trigger the watch above)
      c.set "/foo", "zomg!", :missing do |e|
        case true
        when e.mismatch? # CAS mis-match
          # retry if we must
          c.set "/foo", "zomg!", e.cas do |e|
            if ! e.ok?
              # we give up
            end
          end
        when e.ok?
          e.cas # => "123"
        else
          raise e.err_detail
        end
      end

    end


## Dev

**Clone**
    $ git clone http://github.com/bmizerany/fraggle.git

**Test**
    $ gem install turn
    $ turn
