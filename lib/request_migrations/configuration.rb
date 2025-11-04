# frozen_string_literal: true

module RequestMigrations
  class Configuration
    ##
    # logger defines the logger used by request_migrations.
    #
    # @return [Logger] the logger.
    class_attribute :logger
    self.logger = Logger.new("/dev/null")

    ##
    # request_version_resolver defines how request_migrations should resolve the
    # current version of a request.
    #
    # @return [Proc] the request version resolver.
    class_attribute :request_version_resolver
    self.request_version_resolver = -> req { self.current_version }

    ##
    # version_format defines the version format.
    #
    # @return [Symbol] format
    class_attribute :version_format
    self.version_format = :semver

    ##
    # current_version defines the latest version.
    #
    # @return [String, Integer, Float, nil] the current version.
    class_attribute :current_version
    self.current_version = nil

    ##
    # versions defines past versions and their migrations.
    #
    # @return [Hash<String, Array<Symbol, String, Class>>] past versions.
    class_attribute :versions
    self.versions = {}
  end
end
