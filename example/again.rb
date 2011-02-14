require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do

  c = Fraggle.connect
  c.level = Fraggle::Logger::INFO

  paths = []

  c.walk("/**") do |e|
    paths << e.path+"="+e.value
  end.again do |w|
    # We've been connected to to a new server, Resend the request
    c.send(w)
  end.done do
    puts "## DONE", *paths
  end

end
