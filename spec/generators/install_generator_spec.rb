# frozen_string_literal: true

require 'spec_helper'
require 'generator_spec/test_case'
require 'generators/request_migrations/install_generator'

RSpec.describe RequestMigrations::InstallGenerator, type: :generator do
  include GeneratorSpec::TestCase

  destination File.expand_path('tmp', __dir__)

  after do
    prepare_destination # cleanup the tmp directory
  end

  before do
    prepare_destination
    run_generator
  end

  it 'generates app/migrations/base_migration.rb' do
    assert_file('app/migrations/base_migration.rb')
  end

  it 'generates config/initializers/request_migrations.rb' do
    assert_file('config/initializers/request_migrations.rb')
  end
end
