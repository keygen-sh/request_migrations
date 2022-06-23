# frozen_string_literal: true

module RequestMigrations
  ##
  # Migration represents a migration for a specific version.
  #
  # @example
  #   class CombineNamesForUserMigration < RequestMigrations::Migration
  #     description %(transforms a user's first and last name to a combined name attribute)
  #
  #     migrate if: -> data { data in type: 'user' } do |data|
  #       first_name = data.delete(:first_name)
  #       last_name  = data.delete(:last_name)
  #
  #       data[:name] = "#{first_name} #{last_name}"
  #     end
  #
  #     response if: -> res { res.successful? && res.request.params in controller: 'api/v1/users',
  #                                                                    action: 'show' } do |res|
  #       data = JSON.parse(res.body, symbolize_names: true)
  #
  #       migrate!(data)
  #
  #       res.body = JSON.generate(data)
  #     end
  #   end
  class Migration
    ##
    # @private
    class ConditionalBlock
      def initialize(if: nil, &block)
        @if    = binding.local_variable_get(:if)
        @block = block
      end

      def call(ctx, *args)
        return if
          @if.respond_to?(:call) && !@if.call(*args)

        ctx.instance_exec(*args, &@block)
      end
    end

    module DSL
      def self.extended(klass)
        class << klass
          attr_accessor :description_value,
                        :changeset_value,
                        :request_blocks,
                        :migration_blocks,
                        :response_blocks
        end

        klass.description_value = nil
        klass.request_blocks    = []
        klass.migration_blocks  = []
        klass.response_blocks   = []
      end

      def inherited(klass)
        klass.description_value = description_value.dup
        klass.request_blocks    = request_blocks.dup
        klass.migration_blocks  = migration_blocks.dup
        klass.response_blocks   = response_blocks.dup
      end

      ##
      # description sets the description.
      #
      # @param desc [String] the description
      def description(desc)
        self.description_value = desc
      end

      ##
      # request sets the request migration.
      #
      # @param if [Proc] the proc which determines if the migration should run.
      #
      # @yield [request] the block containing the migration.
      def request(if: nil, &block)
        self.request_blocks << ConditionalBlock.new(if:, &block)
      end

      ##
      # migrate sets the data migration.
      #
      # @param if [Proc] the proc which determines if the migration should run.
      #
      # @yield [data] the block containing the migration.
      def migrate(if: nil, &block)
        self.migration_blocks << ConditionalBlock.new(if:, &block)
      end

      ##
      # response sets the response migration.
      #
      # @param if [Proc] the proc which determines if the migration should run.
      #
      # @yield [response] the block containing the migration.
      def response(if: nil, &block)
        self.response_blocks << ConditionalBlock.new(if:, &block)
      end
    end

    extend DSL

    ##
    # @private
    def migrate_request!(request)
      self.class.request_blocks.each { |block|
        instance_exec(request) { block.call(self, _1) }
      }
    end

    ##
    # @private
    def migrate!(data)
      self.class.migration_blocks.each { |block|
        instance_exec(data) { block.call(self, _1) }
      }
    end

    ##
    # @private
    def migrate_response!(response)
      self.class.response_blocks.each { |block|
        instance_exec(response) { block.call(self, _1) }
      }
    end
  end
end
