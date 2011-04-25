require 'rubygems'
require 'eventmachine'
require 'fraggle'
# This is for testing Fraggle's monitoring of addresses in a cluster.

EM.run do
  c = Fraggle.connect "doozer:?ca=127.0.0.1:8041"
  c.log.level = Logger::DEBUG

  EM.add_periodic_timer(1) do
    p [:addrs, c.addr, c.addrs]
  end
end
