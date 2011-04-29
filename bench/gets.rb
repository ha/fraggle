require 'rubygems'
require 'eventmachine'
require 'fraggle'

reqs = 0

def rget(c, path, rev, &blk)
  c.get(path, rev) do |e|
    blk.call
    rget(c, path, rev, &blk)
  end
end

EM.run do
  c = Fraggle.connect

  EM.add_timer(1) do
    # The primer is done.  Reset `reqs` and do it for real.
    reqs = 0
    EM.add_timer(1) do
      EM.stop_event_loop
    end
  end

  c.rev do |v|
    rget(c, "/ctl/cal/0", v.rev) do
      reqs += 1
    end
  end
end

puts "Result (GET): #{reqs}/sec"
