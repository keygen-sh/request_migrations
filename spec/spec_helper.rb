# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require File.expand_path("../dummy/config/environment", __FILE__)

require "rspec/rails"
require "request_migrations"

RSpec.configure do |config|
  config.expect_with(:rspec) { _1.syntax = :expect }
  config.disable_monkey_patching!
end
