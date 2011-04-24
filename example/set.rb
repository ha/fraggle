require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do
  c = Fraggle.connect

  EM.add_periodic_timer(1) do
    c.get("/hello") do |e|
      p [:e, e]
    end
  end

  c.set('/hello', 'world', 0) do |e|
    p e
  end
end
