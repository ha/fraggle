require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do

  c = Fraggle.connect
  c.log.level = Logger::DEBUG

  c.watch("/example/*") do |e|
    p e
  end.error do |e|
    p [:ASDFASDFDSFASDFADSF, :err, e]
  end

  EM.add_periodic_timer(0.5) do
    c.set("/example/#{rand(10)}", "test", -1)
  end

end
