# frozen_string_literal: true

require "active_support/concern"
require "semverse"
require "logger"
require "request_migrations/gem"
require "request_migrations/configuration"
require "request_migrations/version"
require "request_migrations/migration"
require "request_migrations/migrator"
require "request_migrations/controller"
require "request_migrations/router"
require "request_migrations/railtie"

module RequestMigrations
  ##
  # UnsupportedMigrationError is raised when an invalid migration is provided.
  class UnsupportedMigrationError < StandardError; end

  ##
  # InvalidVersionFormatError is raised when an badly formatted version is provided.
  class InvalidVersionFormatError < StandardError; end

  ##
  # UnsupportedVersionError is raised when an unsupported version is requested.
  class UnsupportedVersionError < StandardError; end

  ##
  # InvalidVersionError is raised when an invalid version is provided.
  class InvalidVersionError < StandardError; end

  ##
  # SUPPORTED_VERSION_FORMATS is a list of supported version formats.
  SUPPORTED_VERSION_FORMATS = %i[
    semver
    date
    float
    integer
    string
  ].freeze

  ##
  # config returns the current config.
  def self.config = @config ||= Configuration.new

  ##
  # @private
  def self.config=(cfg)
    raise ArgumentError, 'invalid config provided' unless
      cfg.is_a?(Configuration)

    @config = cfg
  end

  ##
  # @private
  def self.reset!
    @config = Configuration.new
  end

  ##
  # logger returns the configured logger.
  #
  # @return [Logger]
  def self.logger
    @logger ||= if RequestMigrations.config.logger.respond_to?(:tagged)
                  RequestMigrations.config.logger.tagged(:request_migrations)
                else
                  RequestMigrations.config.logger
                end
  end

  ##
  # configure yields the config.
  #
  # @yield [config]
  def self.configure
    yield config
  end

  ##
  # supported_versions returns an array of supported versions.
  #
  # @return [Array<String, Integer, Float>]
  def self.supported_versions
    [RequestMigrations.config.current_version, *RequestMigrations.config.versions.keys].uniq.freeze
  end
end

