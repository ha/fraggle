require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do

  c = Fraggle.connect

  EM.add_periodic_timer(1) do
    c.rev do |e|
      p [:rev, e.rev]
    end
  end

end
