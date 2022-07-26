# frozen_string_literal: true

module RequestMigrations
  class Testing
    @@config = RequestMigrations::Configuration.new

    ##
    # setup! stores the original config and replaces it with a clone for testing.
    def self.setup!
      @@config = RequestMigrations.config

      RequestMigrations.reset!
      RequestMigrations.configure do |config|
        @@config.config.each { |(k, v)| config.config[k] = v }
      end
    end

    ##
    # teardown! restores the original config.
    def self.teardown!
      RequestMigrations.config = @@config
    end
  end
end
