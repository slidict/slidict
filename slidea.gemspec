# frozen_string_literal: true

require_relative "lib/slidea/version"

Gem::Specification.new do |spec|
  spec.name = "slidea"
  spec.version = Slidea::VERSION
  spec.authors = ["Yusuke Abe"]
  spec.email = ["255824173+abechan1@users.noreply.github.com"]

  spec.summary = "Generate presentation-ready slides from a simple conversation."
  spec.description = "Slidea is a Ruby CLI for turning rough ideas into presentation-ready Markdown slides."
  spec.homepage = "https://labs.slidict.io/slidea/"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/slidict/slidea"
  spec.metadata["changelog_uri"] = "https://github.com/slidict/slidea/releases"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
