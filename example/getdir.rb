require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do

  EM.error_handler do |e|
    $stderr.puts e.message + "\n" + (e.backtrace * "\n")
  end

  c = Fraggle.connect "doozer://127.0.0.1:8041"
  c.level = Fraggle::Logger::INFO

  ents = []
  req = c.getdir "/doozer" do |e|
    ents << e.path
  end

  req.done do
    puts *ents
  end


end
