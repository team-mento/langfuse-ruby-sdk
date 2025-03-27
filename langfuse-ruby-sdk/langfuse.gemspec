lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'langfuse/version'

Gem::Specification.new do |spec|
  spec.name          = 'langfuse'
  spec.version       = Langfuse::VERSION
  spec.authors       = ['Langfuse']
  spec.email         = ['hello@langfuse.com']

  spec.summary       = 'Ruby SDK for the Langfuse observability platform'
  spec.description   = "Langfuse is an open source observability platform for LLM applications. This is the Ruby client for Langfuse's API."
  spec.homepage      = 'https://github.com/langfuse/langfuse-ruby'
  spec.license       = 'MIT'

  spec.files         = Dir.glob('{bin,lib}/**/*') + %w[LICENSE README.md]
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.7.0'

  spec.add_dependency 'concurrent-ruby', '~> 1.2'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.10'
  spec.add_development_dependency 'sidekiq', '~> 6.5'
end
