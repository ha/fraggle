require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do
  c = Fraggle.connect

  EM.add_periodic_timer(1) do
    c.stat("/example") do |e|
      p e
    end.error do |e|
      p [:err, e]
    end
  end

  EM.add_periodic_timer(0.5) do
    c.set("/example/#{rand(10)}", "test", -1)
  end
end
