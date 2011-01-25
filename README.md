# Fraggle
**An EventMachine based Doozer client**

## Install

    $ gem install fraggle

## Use

    require 'rubygems'
    require 'eventmachine'
    require 'fraggle'

    EM.start do
      c = Fraggle.connect "127.0.0.1", 8046

      ## Setting a key
      c.set "/foo", "bar", :missing do |e|
        if ! e.err
          e.cas # => "123"
        end
      end

      c.get "/foo" do |e|
        if err != nil
          e.body     # => "bar"
          e.cas      # => "123"
          e.dir? # => false
        end
      end

      watch = c.watch "/foo" do |e|
        # The event has:
        # ------------------------
        # NOTE:  `err` will be set iff the glob is bad
        # e.err       # => nil
        # e.path      # => "/foo"
        # e.body      # => "bar"
        # e.cas       # => "123"
        # e.set?  # => true
        # e.del?  # => false
        # e.done? # => true
        # ------------------------

        if e.done?
          # This watch was closed, do something if you wish.
        else
          done_something_with(e)

          # Phoney check for example
          if can_stop_watching?(path)
            c.close(watch)
          end
        end

      end

    end


## Dev

**Clone**
    $ git clone http://github.com/bmizerany/fraggle.git

**Test**
    $ gem install turn
    $ turn
