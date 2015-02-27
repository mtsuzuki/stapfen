require 'stapfen/destination'
require 'stapfen/message'

module Stapfen
  class Worker
    KAFKA = :kafka.freeze
    STOMP = :stomp.freeze
    JMS = :jms.freeze

    attr_accessor :client_options, :protocol, :logger, :stapfen_client

    class << self
      attr_accessor :instance_configuration, :consumers, :destructor

      def configure(&configuration_block)
        unless block_given?
          raise Stapfen::ConfigurationError, "Method `configure` requires a block"
        end
        self.instance_configuration = configuration_block
      end

      # Instantiate a new +Worker+ instance and run it
      def run!
        worker = self.new

        @@workers << worker

        handle_signals

        worker.run
      end

      # Main message consumption block
      def consume(config_overrides={}, &consume_block)
        unless block_given?
          raise Stapfen::ConsumeError, "Method `consume` requires a block"
        end
        @consumers ||= []
        @consumers << [config_overrides, consume_block]
      end

      # Optional method, specifes a block to execute when the worker is shutting
      # down.
      def shutdown(&block)
        @destructor = block
      end

      # Return all the currently running Stapfen::Worker instances in this
      # process
      def workers
        @@workers
      end

      # Invoke +exit_cleanly+ on each of the registered Worker instances that
      # this class is keeping track of
      #
      # @return [Boolean] Whether or not we've exited/terminated cleanly
      def exit_cleanly
        return false if workers.empty?

        cleanly = true
        workers.each do |w|
          begin
            w.exit_cleanly
          rescue StandardError => ex
            $stderr.write("Failure while exiting cleanly #{ex.inspect}\n#{ex.backtrace}")
            cleanly = false
          end
        end

        if RUBY_PLATFORM == 'java'
          Stapfen.logger.info 'Telling the JVM to exit cleanly'
          Java::JavaLang::System.exit(0)
        end

        return cleanly
      end

      # Utility method to set up the proper worker signal handlers
      def handle_signals
        return if @@signals_handled

        Signal.trap(:INT) do
          self.exit_cleanly
          exit!
        end

        Signal.trap(:TERM) do
          self.exit_cleanly
        end

        @@signals_handled = true
      end

      # Class variables are put in this method to allow for "reset" style
      # functionality if needed. Useful for testing (see worker_spec.rb).
      def set_class_variable_defaults
        @@signals_handled = false
        @@workers = []
      end

    end

    set_class_variable_defaults

    ############################################################################
    # Instance Methods
    ############################################################################

    def initialize
      instance_configuration = self.class.instance_configuration
      if instance_configuration
        self.configure &instance_configuration
      end
      self.client_options ||= {}
    end

    def configure(&configuration_block)
      self.instance_eval &configuration_block
    end

    def logger
      @logger ||= Stapfen.logger
    end

    # Force the worker to use STOMP as the messaging protocol (default)
    #
    # @return [Boolean]
    def use_stomp!
      begin
        require 'stomp'
      rescue LoadError
        Stapfen.logger.info 'You need the `stomp` gem to be installed to use stomp!'
        raise
      end

      @protocol = STOMP
      return true
    end

    def stomp?
      @protocol == STOMP
    end

    # Force the worker to use JMS as the messaging protocol.
    #
    # *Note:* Only works under JRuby
    #
    # @return [Boolean]
    def use_jms!
      unless RUBY_PLATFORM == 'java'
        raise Stapfen::ConfigurationError, 'You cannot use JMS unless you are running under JRuby!'
      end

      begin
        require 'java'
        require 'jms'
      rescue LoadError
        Stapfen.logger.info 'You need the `jms` gem to be installed to use JMS!'
        raise
      end

      @protocol = JMS
      return true
    end

    def jms?
      @protocol == JMS
    end

    # Force the worker to use Kafka as the messaging protocol.
    #
    # *Note:* Only works under JRuby
    #
    # @return [Boolean]
    def use_kafka!
      unless RUBY_PLATFORM == 'java'
        raise Stapfen::ConfigurationError, 'You cannot use Kafka unless you are running under JRuby!'
      end

      begin
        require 'java'
        require 'hermann'
      rescue LoadError
        Stapfen.logger.info 'You need the `hermann` gem to be installed to use Kafka!'
        raise
      end

      @protocol = KAFKA
      return true
    end

    def kafka?
      @protocol == KAFKA
    end

    def protocol
      @protocol ||= KAFKA
    end

    def run
      case protocol
      when STOMP
        require 'stapfen/client/stomp'
        stapfen_client = Stapfen::Client::Stomp.new(client_options)
      when JMS
        require 'stapfen/client/jms'
        stapfen_client = Stapfen::Client::JMS.new(client_options)
      when KAFKA
        require 'stapfen/client/kafka'
        stapfen_client = Stapfen::Client::Kafka.new(client_options)
      else
        raise 'No client specified'
      end

      logger.info("Running with #{stapfen_client} inside of Thread:#{Thread.current.inspect}")

      stapfen_client.connect

      self.class.consumers.each do |config_overrides, block|
        consumer_config = client_options.merge(config_overrides)
        consumer_topic = consumer_config[:topic]
        consumer_can_unreceive = !(consumer_config.keys & [:max_redeliveries, :dead_letter_queue]).empty?

        # We're taking each block and turning it into a method so that we can
        # use the instance scope instead of the blocks originally bound scope
        # which would be at a class level
        methodized_topic = consumer_topic.gsub(/[.|\-]/, '_').to_sym
        self.class.send(:define_method, methodized_topic, &block)

        stapfen_client.subscribe(consumer_topic, consumer_config) do |message_entity|
          stapfen_message = nil
          if stomp?
            stapfen_message = Stapfen::Message.from_stomp(message_entity)
          end

          if jms?
            stapfen_message = Stapfen::Message.from_jms(message_entity)
          end

          if kafka?
            stapfen_message = Stapfen::Message.from_kafka(message_entity)
          end

          success = self.send(methodized_topic, stapfen_message)

          unless success
            if stapfen_client.can_unreceive? && consumer_can_unreceive
              stapfen_client.unreceive(message_entity, consumer_config)
            end
          end
        end
      end

      begin
        stapfen_client.runloop
        logger.info("Exiting the runloop for #{self}")
      rescue Interrupt
        exit_cleanly
      end
    end

    # Invokes the shutdown block if it has been created, and closes the
    # {{Stomp::Client}} connection unless it has already been shut down
    def exit_cleanly
      logger.info("#{self} exiting ")
      self.class.destructor.call if self.class.destructor

      logger.info 'Killing client'
      begin
        # Only close the client if we have one sitting around
        if stapfen_client
          unless stapfen_client.closed?
            stapfen_client.close
          end
        end
      rescue StandardError => exc
        logger.error "Exception received while trying to close client! #{exc.inspect}"
      end
    end
  end
end
