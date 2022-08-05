# frozen_string_literal: true

require 'spec_helper'
require 'generator_spec/test_case'
require 'generators/request_migrations/migration_generator'

RSpec.describe RequestMigrations::MigrationGenerator, type: :generator do
  include GeneratorSpec::TestCase

  let(:file_name) { 'file_name' }

  destination File.expand_path('tmp', __dir__)

  after do
    prepare_destination # cleanup the tmp directory
  end

  before do
    prepare_destination
    run_generator [file_name]
  end

  it 'generates app/migrations/#{file_name}_migration.rb' do
    assert_file("app/migrations/#{file_name}_migration.rb")
  end
end
