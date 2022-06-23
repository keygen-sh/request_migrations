# frozen_string_literal: true

module RequestMigrations
  class Configuration
    include ActiveSupport::Configurable

    ##
    # logger defines the logger used by request_migrations.
    #
    # @return [Logger] the logger.
    config_accessor(:logger) { Logger.new("/dev/null") }

    ##
    # request_version_resolver defines how request_migrations should resolve the
    # current version of a request.
    #
    # @return [Proc] the request version resolver.
    config_accessor(:request_version_resolver) { -> req { self.current_version } }

    ##
    # version_format defines the version format.
    #
    # @return [Symbol] format
    config_accessor(:version_format) { :semver }

    ##
    # current_version defines the latest version.
    #
    # @return [String, Integer, Float] the current version.
    config_accessor(:current_version) { nil }

    ##
    # versions defines past versions and their migrations.
    #
    # @return [Hash] past versions.
    config_accessor(:versions) { [] }
  end
end
