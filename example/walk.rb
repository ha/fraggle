require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do

  EM.error_handler do |e|
    $stderr.puts e.message + "\n" + (e.backtrace * "\n")
  end

  c = Fraggle.connect "doozer:?ca=127.0.0.1:8046"

  paths = []
  req = c.walk "/**" do |e|
    paths << e.path+"="+e.value
  end

  req.done do
    puts *paths
  end


end
