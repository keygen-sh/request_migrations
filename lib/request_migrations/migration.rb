# frozen_string_literal: true

module RequestMigrations
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
