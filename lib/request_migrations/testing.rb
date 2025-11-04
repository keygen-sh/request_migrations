# frozen_string_literal: true

module RequestMigrations
  class Testing
    @@config = RequestMigrations::Configuration.new

    ##
    # setup! stores the original config and replaces it with a clone for testing.
    def self.setup!
      @@config = RequestMigrations.config

      RequestMigrations.config = @@config.dup
    end

    ##
    # teardown! restores the original config.
    def self.teardown!
      RequestMigrations.config = @@config
    end
  end
end
