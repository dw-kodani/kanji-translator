# frozen_string_literal: true

require_relative "lib/kanji/translator/version"

Gem::Specification.new do |spec|
  spec.name = "kanji-translator"
  spec.version = Kanji::Translator::VERSION
  spec.authors = ["Hiromu Kodani"]
  spec.email = ["kodani@dreaw.jp"]

  spec.summary = "Convert Kanji to Hiragana, Katakana, and Romaji"
  spec.description = <<~DESC.strip
    Fetches readings for Japanese Kanji from yomikatawa.com and converts them
    to hiragana, katakana, or Hepburn-style romaji. Includes timeout/retry
    handling and a simple API.
  DESC
  spec.homepage = "https://github.com/dw-kodani/kanji-translator"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  # If you publish to RubyGems.org, you can remove the following line.
  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/dw-kodani/kanji-translator"
  spec.metadata["changelog_uri"] = "https://github.com/dw-kodani/kanji-translator/blob/master/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "nokogiri", "~> 1.16"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
