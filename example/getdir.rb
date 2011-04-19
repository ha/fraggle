require 'rubygems'
require 'eventmachine'
require 'fraggle'

EM.run do

  c = Fraggle.connect

  ents = []
  req = c.getdir(nil, "/") do |e|
    ents << e.path
  end.done do
    p [:ents, ents]
  end.error do |e|
    raise StandardError.new("err: "+e.inspect)
  end

end
