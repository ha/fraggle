require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do

  c = Fraggle.connect
  c.log.level = Logger::DEBUG

  ents = []
  c.getdir("/") do |e|
    ents << e.path
  end.done do
    p [:ents, ents]
  end.error do |e|
    raise StandardError.new("err: "+e.inspect)
  end

end
