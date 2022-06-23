# frozen_string_literal: true

module RequestMigrations
  ##
  # @private
  class Version
    include Comparable

    attr_reader :format,
                :value

    def initialize(version)
      raise UnsupportedVersionError, "version is unsupported: #{version}" unless
        version.in?(RequestMigrations.supported_versions)

      @format = RequestMigrations.config.version_format.to_sym
      @value  = case @format
                when :semver
                  Semverse::Version.coerce(version)
                when :date
                  Date.parse(version)
                when :integer
                  version.to_i
                when :float
                  version.to_f
                when :string
                  version.to_s
                else
                  raise InvalidVersionFormatError, "invalid version format: #{@format} (must be one of: #{SUPPORTED_VERSION_FORMATS.join(',')}"
                end
    rescue Semverse::InvalidVersionFormat,
           Date::Error
      raise InvalidVersionError, "invalid #{@format} version given: #{version}"
    end

    def <=>(other) = @value <=> Version.coerce(other).value
    def to_s       = @value.to_s

    class << self
      def coerce(version)
        version.is_a?(self) ? version : new(version)
      end
    end

    class Constraint
      attr_reader :format,
                  :value

      def initialize(constraint)
        @format     = RequestMigrations.config.version_format.to_sym
        @constraint = case @format
                      when :semver
                        Semverse::Constraint.coerce(constraint)
                      when :date,
                           :integer,
                           :float,
                           :string
                        raise NotImplementedError, "#{@format} constraints are not supported"
                      else
                        raise InvalidVersionFormatError, "invalid version constraint format: #{@format} (must be one of: #{SUPPORTED_VERSION_FORMATS.join(',')}"
                      end
      end

      def satisfies?(other) = @constraint.satisfies?(other)
    end
  end
end
