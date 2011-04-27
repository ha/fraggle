# Fraggle (v1.0.0.pre.2 is compatible with Doozer 0.5)
**An EventMachine based Doozer client**

## Install

    $ gem install fraggle --pre

## Use

    require 'rubygems'
    require 'eventmachine'
    require 'fraggle'

    EM.start do
      # Fraggle keeps track of this addr plus all others it finds once
      # connected.  In the event of a lost connection, fraggle will attempt
      # other doozers until one accepts or it runs out of options; A NoAddrs
      # exception will be raised if that later happens.
      c = Fraggle.connect "doozerd://127.0.0.1:8046"

      req = c.get("/foo") do |e|
        e.value   # => "bar"
        e.rev     # => 123
      end

      req.error do |e|
        e.err_code   # => nil
        e.err_detail # => nil
      end

      watch = c.watch("/foo") do |e|
        # The event has:
        # ------------------------
        e.err_code   # => nil
        e.err_detail # => nil
        e.path       # => "/foo"
        e.value      # => "bar"
        e.rev        # => 123
        e.set?       # => true
        e.del?       # => false

        do_something_with(e)

        # Phoney check for example
        if can_stop_watching?(path)
          watch.cancel
        end
      end

      ## Setting a key (this will trigger the watch above)
      req = c.set("/foo", "zomg!", 0) do |e|
        # Success!
      end.error do |e|
        if e.mismatch?
          # There was a rev mismatch, handle this.
        else
          raise e.err_detail
        end
      end

      # Knowning when a command is done is useful in some cases.
      # Use the `done` callback for those situations.
      ents = []
      c.getdir("/test") do |e|
        ents << e
      end.done do
        p ents
      end

      c.get("/nothere") do |e|
        e.missing? # => true
      end

    end

## Consistency

Fraggle read commands take a `rev`.  If no rev is given, Doozer will reply with
the most up-to-date data.   If you need to do multiple reads at certain
point in time for consistency, use the `rev` command.

    c.rev do |v|
      c.get("/a", v.rev) { ... }
      c.get("/b", v.rev) { ... }
      c.get("/c", v.rev) { ... }
    end

This also means you can go back in time or into the future!

    # This will not yield until the data store is at revision 100,000
    c.get("/a", 100_000) { ... }

NOTE:  Doozer's data store is a persistent data structure.  You can reference the
stores history as far back as it is configured to hold it.  The default is
360,000 revisions.  See [data model][] for more information.

## High Availability

  Fraggle has mechanisms to gracefully deal with connection loss.  They are:

*Resend / Connection loss*

  When a connection is lost and Fraggle successfully reconnects to another
  Doozer node, Fraggle will resend most pending requests to the new connection.
  This means you will not miss events; Even events that happened while you were
  disconnected!  All read commands will pick up where they left off.  This is
  valuable to understand because it means you don't need to code for failure on
  reads; Fraggle gracefully handles it for you.

  Write commands will be resent if their `rev` is greater than 0.  These are
  idempotent requests.  A rev of 0 will cause that request's error
  callback to be invoked with a Fraggle::Connection::Disconnected response.
  You will have to handle these yourself because Fraggle cannot know whether or
  not it's safe to retry on your behalf.

## Dev

**Clone**

    $ git clone http://github.com/bmizerany/fraggle.git

**Test**

    $ gem install turn

    $ turn


[data model]: https://github.com/ha/doozerd/blob/master/doc/data-model.md
