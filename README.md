# Fraggel
**An EventMachine based Doozer client**

## Install

    $ gem install fraggel

## Use

    require 'rubygems'
    require 'eventmachine'
    require 'fraggel'

    EM.start do
      client = Fraggel.connect :local, "127.0.0.1", 8046

      ## Setting a key
      client.set "/foo", "bar", :missing do |cas, err|
        if err != nil
          cas      # => "123"
          cas.dir? # => false
        end
      end

      client.get "/foo" do |body, cas, err|
        if err != nil
          body     # => "bar"
          cas      # => "123"
          cas.dir? # => false
        end
      end

      watch = client.watch "/foo" do |path, body, cas, err|
        # The event has:
        # ------------------------
        # NOTE:  `err` will be set iff the glob is bad
        # err       # => nil
        # path      # => "/foo"
        # body      # => "bar"
        # cas       # => "123"
        # cas.set?  # => true
        # cas.del?  # => false
        # ------------------------

        # Phoney check for example
        if can_stop_watching?(path)
          client.close(watch)
        end
      end

    end


## Develop

**Clone**
    $ git clone http://github.com/bmizerany/fraggel.git

**Test**
    $ gem install turn
    $ turn
