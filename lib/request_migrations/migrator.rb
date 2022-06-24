# frozen_string_literal: true

module RequestMigrations
  class Migrator
    ##
    # Migrator represents a versioned migration from one version to another.
    #
    # @param from [String, Integer, Float] the current version.
    # @param to [String, Integer, Float] the target version.
    def initialize(from:, to:)
      @current_version = Version.new(from)
      @target_version  = Version.new(to)
    end

    ##
    # migrate! attempts to apply all matching migrations on data.
    #
    # @param data [Any] the data to be migrated.
    #
    # @return [void]
    def migrate!(data:)
      logger.debug { "Migrating from #{current_version} to #{target_version} (#{migrations.size} potential migrations)" }

      migrations.each_with_index { |migration, i|
        logger.debug { "Applying migration #{migration} (#{i + 1}/#{migrations.size})" }

        migration.new.migrate!(data)
      }

      logger.debug { "Migrated from #{current_version} to #{target_version}" }
    end

    private

    attr_accessor :current_version,
                  :target_version

    def logger = RequestMigrations.logger

    def migrations
      @migrations ||=
        RequestMigrations.config.versions
          .filter { |(version, _)| Version.new(version).between?(target_version, current_version) }
          .sort
          .reverse
          .flat_map { |(_, migrations)| migrations }
          .map { |migration|
            case migration
            when Symbol
              migration.to_s.classify.constantize
            when String
              migration.classify.constantize
            when Class
              migration
            else
              raise UnsupportedMigrationError, "migration type is unsupported: #{migration}"
            end
          }
    end
  end
end
