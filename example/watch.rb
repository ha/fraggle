require 'fraggel'

Glob = "/letters/*"

EM.run do
  client = Fraggel.connect 8046

  puts "Watching #{Glob}"

  client.watch Glob do |path, body, cas, err|
    p [:noticed, path, body, cas, err]
  end
end
