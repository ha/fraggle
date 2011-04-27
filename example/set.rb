require 'rubygems'
require 'eventmachine'
require 'fraggle'

MaxInt64 = (1<<62)-1

EM.run do
  c = Fraggle.connect
  c.log.level = Logger::DEBUG

  EM.add_periodic_timer(1) do
    c.get("/hello") do |e|
      p [:e, e]
    end
  end

  c.set('/hello', 'world', MaxInt64) do |e|
    p [:set, e]
  end
end
