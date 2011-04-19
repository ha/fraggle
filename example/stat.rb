require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do

  c = Fraggle.connect

  EM.add_periodic_timer(1) do
    c.stat("/example") do |e|
      p e
    end
  end

  EM.add_periodic_timer(0.5) do
    c.set(0, "/example/#{rand(10)}", "test")
  end

end
