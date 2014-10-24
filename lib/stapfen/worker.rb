require 'stomp'
require 'stapfen/logger'
require 'stapfen/destination'
require 'stapfen/message'

module Stapfen
  class Worker
    include Stapfen::Logger

    # Class variables!
    @@signals_handled = false
    @@workers = []

    class << self
      attr_accessor :configuration, :consumers, :logger, :destructor
    end

    # Instantiate a new +Worker+ instance and run it
    def self.run!
      worker = self.new

      @@workers << worker

      handle_signals

      worker.run
    end

    # Expects a block to be passed which will yield the appropriate
    # configuration for the Stomp gem. Whatever the block yields will be passed
    # directly into the {{Stomp::Client#new}} method
    def self.configure(&block)
      unless block_given?
        raise Stapfen::ConfigurationError
      end
      @configuration = block
    end

    # Force the worker to use STOMP as the messaging protocol (default)
    #
    # @return [Boolean]
    def self.use_stomp!
      begin
        require 'stomp'
      rescue LoadError
        puts "You need the `stomp` gem to be installed to use stomp!"
        raise
      end

      @protocol = 'stomp'
      return true
    end

    def self.stomp?
      @protocol.nil? || @protocol == 'stomp'
    end

    # Force the worker to use JMS as the messaging protocol.
    #
    # *Note:* Only works under JRuby
    #
    # @return [Boolean]
    def self.use_jms!
      unless RUBY_PLATFORM == 'java'
        raise Stapfen::ConfigurationError, "You cannot use JMS unless you're running under JRuby!"
      end

      begin
        require 'java'
        require 'jms'
      rescue LoadError
        puts "You need the `jms` gem to be installed to use JMS!"
        raise
      end

      @protocol = 'jms'
      return true
    end

    def self.jms?
      @protocol == 'jms'
    end

    # Force the worker to use Kafka as the messaging protocol.
    #
    # *Note:* Only works under JRuby
    #
    # @return [Boolean]
    def self.use_kafka!
      unless RUBY_PLATFORM == 'java'
        raise Stapfen::ConfigurationError, "You cannot use Kafka unless you're running under JRuby!"
      end

      begin
        require 'java'
        require 'hermann'
      rescue LoadError
        puts "You need the `hermann` gem to be installed to use Kafka!"
        raise
      end

      @protocol = 'kafka'
      return true
    end

    def self.kafka?
      @protocol == 'kafka'
    end

    # Optional method, should be passed a block which will yield a {{Logger}}
    # instance for the Stapfen worker to use
    def self.log(&block)
      @logger = block
    end

    # Main message consumption block
    def self.consume(queue_name, headers={}, &block)
      unless block_given?
        raise Stapfen::ConsumeError, "Cannot consume #{queue_name} without a block!"
      end
      @consumers ||= []
      @consumers << [queue_name, headers, block]
    end

    # Optional method, specifes a block to execute when the worker is shutting
    # down.
    def self.shutdown(&block)
      @destructor = block
    end

    # Return all the currently running Stapfen::Worker instances in this
    # process
    def self.workers
      @@workers
    end

    # Invoke +exit_cleanly+ on each of the registered Worker instances that
    # this class is keeping track of
    #
    # @return [Boolean] Whether or not we've exited/terminated cleanly
    def self.exit_cleanly
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
        info "Telling the JVM to exit cleanly"
        Java::JavaLang::System.exit(0)
      end

      return cleanly
    end

    # Utility method to set up the proper worker signal handlers
    def self.handle_signals
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



    ############################################################################
    # Instance Methods
    ############################################################################

    attr_accessor :client

    def run
      if self.class.stomp?
        require 'stapfen/client/stomp'
        @client = Stapfen::Client::Stomp.new(self.class.configuration.call)
      elsif self.class.jms?
        require 'stapfen/client/jms'
        @client = Stapfen::Client::JMS.new(self.class.configuration.call)
      elsif self.class.kafka?
        require 'stapfen/client/kafka'
        @client = Stapfen::Client::Kafka.new(self.class.configuration.call)
      end

      debug("Running with #{@client} inside of Thread:#{Thread.current.inspect}")

      @client.connect

      self.class.consumers.each do |name, headers, block|
        unreceive_headers = {}
        [:max_redeliveries, :dead_letter_queue].each do |sym|
          unreceive_headers[sym] = headers[sym] if headers.has_key? sym
        end

        # We're taking each block and turning it into a method so that we can
        # use the instance scope instead of the blocks originally bound scope
        # which would be at a class level
        method_name = name.gsub(/[.|\-]/, '_').to_sym
        self.class.send(:define_method, method_name, &block)

        client.subscribe(name, headers) do |m|
          message = nil
          if self.class.stomp?
            message = Stapfen::Message.from_stomp(m)
          end

          if self.class.jms?
            message = Stapfen::Message.from_jms(m)
          end

          if self.class.kafka?
            message = Stapfen::Message.from_kafka(m)
          end

          success = self.send(method_name, message)

          unless success
            if client.can_unreceive? && !unreceive_headers.empty?
              client.unreceive(m, unreceive_headers)
            end
          end
        end
      end

      begin
        client.runloop
        warn("Exiting the runloop for #{self}")
      rescue Interrupt
        exit_cleanly
      end
    end

    # Invokes the shutdown block if it has been created, and closes the
    # {{Stomp::Client}} connection unless it has already been shut down
    def exit_cleanly
      info("#{self} exiting ")
      self.class.destructor.call if self.class.destructor

      info "Killing client"
      begin
        # Only close the client if we have one sitting around
        if client
          unless client.closed?
            client.close
          end
        end
      rescue StandardError => exc
        error "Exception received while trying to close client! #{exc.inspect}"
      end
    end
  end
end
