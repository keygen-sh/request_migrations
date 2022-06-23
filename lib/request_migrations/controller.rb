# frozen_string_literal: true

module RequestMigrations
  module Controller
    ##
    # @private
    class Migrator < Migrator
      def initialize(request:, response:, **kwargs)
        super(**kwargs)

        @request  = request
        @response = response
      end

      def migrate!
        logger.debug { "Migrating from #{current_version} to #{target_version} (#{migrations.size} potential migrations)" }

        migrations.each_with_index { |migration, i|
          logger.debug { "Applying migration #{migration} (#{i + 1}/#{migrations.size})" }

          migration.new.migrate_request!(request)
        }

        yield

        migrations.each_with_index { |migration, i|
          logger.debug { "Applying migration #{migration} (#{i + 1}/#{migrations.size})" }

          migration.new.migrate_response!(response)
        }

        logger.debug { "Migrated from #{current_version} to #{target_version}" }
      end

      private

      attr_accessor :request,
                    :response

      def logger
        if RequestMigrations.config.logger.respond_to?(:tagged)
          RequestMigrations.logger.tagged(request&.request_id)
        else
          RequestMigrations.logger
        end
      end
    end

    ##
    # Migrations is controller middleware that automatically applies migrations.
    #
    # @example
    #   class ApplicationController < ActionController::API
    #     include RequestMigrations::Controller::Migrations
    #   end
    #
    # @raise [RequestMigrations::UnsupportedVersionError]
    module Migrations
      extend ActiveSupport::Concern

      included do
        around_action :apply_migrations!

        private

        def apply_migrations!
          current_version = RequestMigrations.config.current_version
          target_version  = RequestMigrations.config.request_version_resolver.call(request)

          migrator = Migrator.new(from: current_version, to: target_version, request:, response:)
          migrator.migrate! { yield }
        end
      end
    end

    module Constraints
      extend ActiveSupport::Concern

      included do
        # TODO(ezekg) Implement controller-level version constraints.
      end
    end
  end
end
