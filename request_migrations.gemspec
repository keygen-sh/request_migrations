require_relative "lib/request_migrations/gem"

Gem::Specification.new do |spec|
  spec.name        = "request_migrations"
  spec.version     = RequestMigrations::VERSION
  spec.authors     = ["Zeke Gabrielse"]
  spec.email       = ["oss@keygen.sh"]
  spec.summary     = "Write request and response migrations for your Ruby on Rails API."
  spec.description = "Make breaking API changes without breaking things by using request_migrations to craft backwards-compatible migrations for API requests, responses, and more. Inspired by Stripe's API versioning strategy."
  spec.homepage    = "https://github.com/keygen-sh/request_migrations"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.1"
  spec.files                 = %w[LICENSE CHANGELOG.md CONTRIBUTING.md SECURITY.md README.md] + Dir.glob("lib/**/*")
  spec.require_paths         = ["lib"]

  spec.add_dependency "rails",    ">= 6.0"
  spec.add_dependency "semverse", "~> 3.0"

  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "generator_spec"
end
