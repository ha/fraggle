require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do

  EM.error_handler do |e|
    $stderr.puts e.message + "\n" + (e.backtrace * "\n")
  end

  c = Fraggle.connect "doozer://127.0.0.1:8041"
  c.level = Fraggle::Client::DEBUG

  c.session do
    c.debug "established connection!"
  end
end
