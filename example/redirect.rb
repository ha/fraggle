require 'rubygems'
require 'fraggle'

EM.run do
  # Connect to a slave (be sure this is a slave)
  c = Fraggle.connect("doozer:?ca=127.0.0.1:8042&ca=127.0.0.1:8041")
  c.log.level = Logger::DEBUG

  # Wait for rev 100,000
  c.set(-1, "/foo", "bar") do |e|
    p ["This should not be!", e]
  end.error do |e|
    p [:err, e]
  end.done do
    p [:done, "This should not be!"]
  end
end
