# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "fraggle/version"

Gem::Specification.new do |s|
  s.name        = "fraggle"
  s.version     = Fraggle::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Blake Mizerany"]
  s.email       = ["blake.mizerany@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{An EventMachine Client for Doozer}
  s.description = s.summary

  s.rubyforge_project = "fraggle"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "beefcake", "~>0.3"
  s.add_dependency "eventmachine"

  s.add_development_dependency "turn"
end
