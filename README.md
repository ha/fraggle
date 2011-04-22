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
      # NoAddrs will be raised if that later happens.
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

        do_something_with(e)

        # Phoney check for example
        if can_stop_watching?(path)
          watch.cancel
        end
      end

      ## Setting a key (this will trigger the watch above)
      req = c.set(0, "/foo", "zomg!") do |e|
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
      req = c.getdir("/test") do |e|
        ents << e
      end.done do
        p ents
      end

    end

## Consitency

Fraggle read commands take an `rev`.  If no rev is given, Doozer will reply with
the most up-to-date data.   If you need to do multiple reads at certian
point in time for consistancy, use the `rev` command.

    c.rev do |v|
      c.get("/a", v.rev) { ... }
      c.get("/b", v.rev) { ... }
      c.get("/c", v.rev) { ... }
    end

This also means you can go back in time or into the future!

    # This will not return until the data store is at revision 100,000
    c.get("/a", 100_000) { ... }

## High Availablity

  Fraggle has mechinisms built into to deal the connection loss.  They are:

*Monitoring cluster activity*

  Fraggle monitors new Doozer nodes that come and go.  This enables Doozer to
  keep an up-to-date list of available nodes it can connect to in the case of
  a connection loss.

*Resend*

  Fraggle will resend most pending requests to a new connection.  This means you
  will not miss events; Even events that happend while you were reconnecting!
  All read commands will pick up where they left off.  This is valuable to
  understand because it means you don't need to code for failure on reads;
  Fraggle gracefully handles it for you.

  Write commands will be resent if their `rev` is greater than 0.  These are
  idempotent requests.  A rev of 0 or less will cause that requests  error
  callback will be invoked with a Fraggle::Connection::Disconnected response.
  You will have to handle these yourself because Fraggle cannot know weather or
  not it's safe to retry on your behalf.

  You can use the `rev` on reads to inspect the data store on a reconnect to
  determine if it is safe to retry.  It is possible you don't care about
  retrying the write; in that case, you don't need to worry about the error.

  For commands with multiple responses (i.e. `walk`, `watch`, `getdir`), Fraggle
  will update their offset and limit as each response comes in.  This means
  if you disconnect in the middle of the responses, Fraggle will gracefully
  resend the requests making it appear nothing happend and continue giving you
  the remaining responses.

## Dev

**Clone**
    $ git clone http://github.com/bmizerany/fraggle.git

**Test**
    $ gem install turn
    $ turn
