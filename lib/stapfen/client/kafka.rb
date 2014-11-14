begin
  require 'hermann'
  require 'hermann/consumer'
rescue LoadError => e
  if RUBY_PLATFORM == 'java'
    raise
  end
end

require 'stapfen/destination'

module Stapfen
  module Client
    class Kafka
      attr_reader :connection, :producer

      # Initialize a Kafka client object
      #
      # @params [Hash] configuration object
      # @option configuration [String] :topic The kafka topic
      # @option configuration [String] :groupId The kafka groupId
      # @option configuration [String] :zookeepers Comma separated list of zookeepers
      # @option configuration [Hash]   :consumer_opts Options for Hermann consumer
      #
      # @raises [ConfigurationError] if required configs are not present
      def initialize(configuration)
        super()
        @config     = configuration
        @topic      = @config[:topic]
        @groupId    = @config[:groupId]
        @zookeepers = @config[:zookeepers]
        opts        = @config[:consumer_opts]
        raise ConfigurationError unless @groupId && @zookeepers
        @connection = Hermann::Consumer.new(@topic, @groupId, @zookeepers, opts)
      end

      # This method is not implemenented
      def connect(*args)
        # No-op
      end

      # Cannot unreceive
      def can_unreceive?
        false
      end

      # API compatibilty method, doesn't actually indicate that the connection
      # is closed. Will only return true if no connection currently exists
      #
      # @return [Boolean]
      def closed?
        return connection.nil?
      end

      # Closes the consumer threads created by kafka.
      #
      # @return [Boolean] True/false depending on whether we actually closed
      #   the connection
      def close
        return false unless @connection
        @connection.shutdown
        @connection = nil
        return true
      end

      # Subscribes to a destination (i.e. kafka topic) and consumes messages
      #
      # @params [Destination] source of messages to consume
      #
      # @params [Hash] Not used
      #
      # @params [block] block to yield consumed messages
      def subscribe(destination, headers={}, &block)
        destination = Stapfen::Destination.from_string(destination)
        connection.consume(destination.as_kafka, &block)
      end

      def runloop
        loop do
          sleep 1
        end
      end

    end
  end
end
