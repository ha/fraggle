require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do

  c = Fraggle.connect

  c.watch 0, "/example/*" do |e|
    p e
  end

  EM.add_periodic_timer(0.5) do
    c.set(-1, "/example/#{rand(10)}", "test")
  end

end
