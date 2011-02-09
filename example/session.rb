require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do

  EM.error_handler do |e|
    $stderr.puts e.message + "\n" + (e.backtrace * "\n")
  end

  c = Fraggle.connect "doozer:?ca=127.0.0.1:8041&ca=123.0.0.1:9999"
  c.level = Fraggle::Client::DEBUG

  c.session "example" do
    c.debug "established connection!"
  end
end
