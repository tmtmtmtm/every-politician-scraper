# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'every_politician_scraper/version'

Gem::Specification.new do |spec|
  spec.required_ruby_version = '>= 2.6.0'
  spec.name                  = 'every-politician-scraper'
  spec.version               = EveryPoliticianScraper::VERSION
  spec.authors               = ['Tony Bowden']
  spec.email                 = ['tony@tmtm.com']

  spec.summary  = 'Scrape multiple sources of political data and compare them'
  spec.homepage = 'https://github.com/tmtmtmtm/every-politician-scraper/'
  spec.license  = 'MIT'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'daff', '~> 1.3.0'
  spec.add_runtime_dependency 'scraped', '~> 0.5'

  spec.add_development_dependency 'bundler', '~> 2.1'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'pry', '~> 0.10'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'reek'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-minitest'
  spec.add_development_dependency 'rubocop-performance'
  spec.add_development_dependency 'rubocop-rake'
  spec.add_development_dependency 'warning', '~> 1.1'
  spec.add_development_dependency 'webmock', '~> 3.10.0'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
