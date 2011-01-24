require 'rubygems'
require 'fraggel'

EM.run do
  c = Fraggel.connect
  c.session!
end
