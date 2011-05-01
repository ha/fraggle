require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do
  # In the event of a lost connection, fraggle will attempt
  # other doozers until one accepts or it runs out of options; A NoAddrs
  # exception will be raised if that later happens.

  c = Fraggle.connect

  c.rev do |v|
    c.get(v.rev, "/foo") do |e|
      p [:get, e]
      if e.ok?
        e.value    # => nil
        e.rev      # => 0
        e.missing? # => true
      else
        e.err_code # => nil
        e.err_detail # => nil
      end
    end

    ## Obtain the current revision the store is at and watch from then on for
    ## any SET or DEL to /foo.
    c.wait(v.rev, "/foo") do |e|
      # The event has:
      # ------------------------
      e.err_code   # => nil
      e.err_detail # => nil
      e.path       # => "/foo"
      e.value      # => "zomg!"
      e.rev        # => 123
      e.set?       # => true
      e.del?       # => false

      p [:wait, e]
    end
  end

  ## Setting a key (this will trigger the watch above)
  c.set(Fraggle::Clobber, "/foo", "zomg!") do |e|
    # Success!
    case e.err_code
    when Fraggle::REV_MISMATCH
      # We didn't win
    when nil
      # Success!
    else
      fail "something bad happened: " + e.inspect
    end
  end

end
