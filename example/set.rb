require 'rubygems'
require 'eventmachine'
require 'lib/fraggel'

EM.run do
  client = Fraggel.connect "127.0.0.1", 8046

  client.call "SET", ["/foo", "bar", "0"] do |cas, err|
    p [:set, cas, err]
  end
end
