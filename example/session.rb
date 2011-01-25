require 'rubygems'
require 'fraggle'

EM.run do
  c = Fraggle.connect
  c.session do
    c.get "/ping" do |e|
      p [:e, e]
    end
  end
end
