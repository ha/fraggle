require 'rubygems'
require 'fraggle'

# This example assumes you have a Doozer with CAL privledges listening on port
# 8041 and a Doozer sink listening on 8042.  This example will connect to the
# sink and attempt a write operation that will be redirected by the sink.
# Fraggle will pick the only remaining addr it has which is the CAL Doozer and
# retry the write operation.

EM.run do
  # Connect to a slave (be sure this is a slave)
  c = Fraggle.connect("doozer:?ca=127.0.0.1:8042&ca=127.0.0.1:8041")
  c.log.level = Logger::DEBUG

  a = c.set("/foo", "bar", -1) do |e|
    # This shouldn't happen
    p [:valid, a, e]
  end.error do |e|
    p [:err, a, e]
  end

  b = c.set("/foo", "bar", 1) do |e|
    p [:valid, b, e]
  end.error do |e|
    # This shouldn't happen
    p [:err, b, e]
  end
end
