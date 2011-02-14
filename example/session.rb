require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do

  EM.error_handler do |e|
    $stderr.puts e.message + "\n" + (e.backtrace * "\n")
  end

  c = Fraggle.connect
  c.level = Fraggle::Client::DEBUG

  c.session "example." do |session_id|
    c.debug "established session (#{session_id})!"
  end
end
