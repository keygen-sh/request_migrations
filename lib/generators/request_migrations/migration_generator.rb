# frozen_string_literal: true

require 'rails/generators'

module RequestMigrations
  # A default migration generator class
  class MigrationGenerator < Rails::Generators::NamedBase
    namespace 'request_migrations:migration'

    ACTIONS = %w[index show create update delete].freeze
    DESCRIPTION = 'description goes here'

    source_root File.expand_path('../templates', __dir__)

    class_option :actions, aliases: '-a', type: :array,
                           desc: "Select specific actions to generate (#{ACTIONS.join(', ')})"

    class_option :description, aliases: '-d', type: :string,
                               desc: 'Add migration description'

    def start
      @actions = options[:actions] || ACTIONS
      @description = options[:description] || DESCRIPTION

      template 'migration.rb', "app/migrations/#{file_name}_migration.rb"
    end
  end
end
