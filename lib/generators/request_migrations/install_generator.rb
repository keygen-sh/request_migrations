# frozen_string_literal: true

require 'rails/generators'

module RequestMigrations
  # Intial Files Generator class
  class InstallGenerator < Rails::Generators::Base
    namespace 'request_migrations:install'

    desc 'Generates a request_migrations initializer configuration plus a base migration file.'

    source_root File.expand_path('templates', __dir__)

    class_option :api_version, type: :string, aliases: '-v', default: '1.1', desc: 'API current version'
    class_option :api_prev_version, type: :string, aliases: '-pv', default: '1.0', desc: 'API previoues version'

    def copy_base_file
      copy_file '../../templates/base_migration.rb', 'app/migrations/base_migration.rb'
    end

    def create_initializer
      @version = options[:api_version] || '1.1'
      @prev_version = options[:api_prev_version] || '1.0'

      template '../../templates/request_migrations.rb', 'config/initializers/request_migrations.rb'
    end
  end
end
