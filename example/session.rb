require 'rubygems'
require 'fraggel'

EM.run do
  c = Fraggel.connect
  c.session do
    c.get "/ping" do |e|
      p [:e, e]
    end
  end
end
