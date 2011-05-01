# Fraggle (v3.0.0 is compatible with Doozer 0.6)

Fraggle currently is only a raw interface to Doozer 0.6.
Sugar for `WALK`, `GETDIR`, etc are to come in a later version of v3.0.0.

**An EventMachine based Doozer client**

## Install

    $ gem install fraggle

## Use

*Connecting to a cluster*

Use `Fraggle.connect`.  It takes an optional [doozer uri][] (String).  If no
parameters are given, it will use the DOOZER_URI` environment variable if
present, otherwise it will default to the uri containing the default doozer
addresses with IP 127.0.0.1 and ports 8046, 8041, 8042, 8043.

*simple example*

    require 'rubygems'
    require 'eventmachine'
    require 'fraggle'

    EM.start do
      # In the event of a lost connection, fraggle will attempt
      # other doozers until one accepts or it runs out of options; A NoAddrs
      # exception will be raised if that later happens.

      c = Fraggle.connect

      req = c.get("/foo") do |e|
        if e.ok?
          e.value    # => nil
          e.rev      # => 0
          e.missing? # => true
        else
          e.err_code # => Fraggle::<CONST>
          e.err_detail # => "bad path" or something
        end
      end

      c.rev do |v|
        ## Obtain the current revision the store is at and watch from then on for
        ## any SET or DEL to /foo.
        c.wait("/foo", v.rev) do |e|
          # The event has:
          # ------------------------
          e.err_code   # => nil
          e.err_detail # => nil
          e.path       # => "/foo"
          e.value      # => "zomg!"
          e.rev        # => 123
          e.set?       # => true
          e.del?       # => false
        end
      end

      ## Setting a key (this will trigger the watch above)
      req = c.set("/foo", "zomg!", 0) do |e|
        # Success!
        case e.err_code
        when Fraggle::REV_MISMATCH
          # We didn't win
        when nil
          # Success!
        else
          fail "something bad happened"
        end
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

## Commands

Each command behaves according to the [proto spec][], respectively.
Their `blk`s are called with one parameter, a `Fraggle::Response`, when a response is
returned from the server.

`set(path, value, rev, &blk)`

`del(path, rev, &blk)`

`get(path, rev, &blk)`

`getdir(path, rev, offset, &blk)`

`walk(path, rev, offset, &blk)`

`wait(path, rev, &blk)`

`rev(&blk)`

`stat(path, rev, &blk)`

`watch(path, rev, &blk)`

## Sugar commands

`getdir_all(path, rev, off=0, lim=MaxInt64, ents=[], &blk)`

Behaves like `getdir` but collects `ents`, starting at `off` until all or `lim`
entries are read. When done `blk` is called with the result as the first
parameter or an error as the second.  Depending on the response, one or the
other will be set and the other with be `nil`.

`walk_all(path, rev, off=0, lim=MaxInt64, ents=[], &blk)`

Behaves like `walk` but collects `ents`, starting at `off` until all or `lim`
entries are read. When done `blk` is called with the result as the first
parameter or an error as the second.  Depending on the response, one or the
other will be set and the other with be `nil`.

## Dev

**Clone**

    $ git clone http://github.com/ha/fraggle.git

**Test**

    $ gem install turn

    $ turn

**Mailing List**

Please join the Doozer mailing list for help:
http://groups.google.com/forum/#!forum/doozer

[data model]: https://github.com/ha/doozerd/blob/master/doc/data-model.md
[doozer uri]: https://github.com/ha/doozerd/blob/master/doc/uri.md
[proto spec]: https://github.com/ha/doozerd/blob/master/doc/proto.md
