# frozen_string_literal: true

module RequestMigrations
  module Router
    module Constraints
      ##
      # @private
      class VersionConstraint
        def initialize(constraint:)
          @constraint = Version::Constraint.new(constraint)
        end

        def matches?(request)
          version = Version.coerce(resolver.call(request))

          @constraint.satisfies?(version)
        end

        private

        def resolver = RequestMigrations.config.request_version_resolver
      end

      ##
      # version_constraint is a router constraint that resolves routes for
      # specific versions.
      #
      # @param constraint [String] the version constraint.
      #
      # @yield the block when the constraint is satisfied.
      #
      # @example
      #   Rails.application.routes.draw do
      #     version_constraint '> 1.0' do
      #       resources :some_new_resource
      #     end
      #   end
      def version_constraint(constraint, &block)
        constraints VersionConstraint.new(constraint:) do
          instance_eval(&block)
        end
      end
    end
  end
end
