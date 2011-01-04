Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=

  s.name = 'fraggel'
  s.version = '0.1.0'
  s.date = '2011-01-03'

  s.description = "An evented doozer client"
  s.summary     = s.description

  s.authors = ["Blake Mizerany", "Keith Rarick", "Chris Moos"]

  # = MANIFEST =
  s.files = %w[LICENSE README.md] +
    Dir["{lib,test,example}/**/*.rb"]

  # = MANIFEST =

  s.test_files = s.files.select {|path| path =~ /^test\/.*_test.rb/}

  s.extra_rdoc_files = %w[README.md LICENSE]

  s.has_rdoc = true
  s.homepage = "http://github.com/bmizerany/fraggel"
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Sinatra", "--main", "README.rdoc"]
  s.require_paths = %w[lib]
  s.rubyforge_project = 'fraggel'
  s.rubygems_version = '1.1.1'
end
