# Fraggle (v4.0.0.pre.1 is compatible with Doozer 0.6)

Fraggle currently is only a raw interface to Doozer 0.6.

**An EventMachine based Doozer client**

## Install

(For pre-releases, use `--pre`)

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
            err.err_code   # => nil
            err.err_detail # => nil
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

## Consistency

Fraggle read commands take a `rev`.  If no rev is given, Doozer will reply with
the most up-to-date data.   If you need to do multiple reads at certain
point in time for consistency, use the `rev` command.

    c.rev do |v|
      c.get(v, "/a") { ... }
      c.get(v, "/b") { ... }
      c.get(v, "/c") { ... }
    end

This also means you can go back in time or into the future!

    # This will not yield until the data store is at revision 100,000
    c.get(100_000, "/a") { ... }

NOTE:  Doozer's data store is a [persistent data structure][pd].  You can reference the
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

Each command below behaves according to the [proto spec][], respectively.
Their `blk`s are called with two parameters, a `Fraggle::Response` as the first
or a `Fraggle::Connection::ResponseError` as the second if a response is
returned from the server.

`set(rev, path, value, &blk)`

`del(rev, path, &blk)`

`get(rev, path, &blk)`

`wait(rev, path, &blk)`

`rev(&blk)`

`stat(rev, path, &blk)`

## Sugar commands

`watch(rev, path, &blk)`

Watches `path` (a glob pattern) for changes, from `rev` in history on.  Its
`blk` is called with a `Fraggle::Response` for each event.

`getdir(rev, path, off=0, lim=MaxInt64, ents=[], &blk)`

Behaves like `getdir` but collects `ents`, starting at `off` until all or `lim`
entries are read. When done, `blk` is called with the result (an `Array`) as the
first parameter or a `Fraggle::Connection::Response` as the second.  Depending
on the response, one or the other will be set and the other with be `nil`.

`walk(rev, path, off=0, lim=MaxInt64, ents=[], &blk)`

Like `getdir`, but but path is a glob pattern and each result contains a `path`,
`value`, and `rev`.

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
[pd]: http://en.wikipedia.org/wiki/Persistent_data_structure
