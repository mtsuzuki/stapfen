module Stapfen
  class Message
    attr_reader :message_id, :body, :original, :destination

    def initialize(opts={})
      super()
      @body        = opts[:body]
      @destination = opts[:destination]
      @message_id  = opts[:message_id]
      @original    = opts[:original]
    end

    # Create an instance of {Stapfen::Message} from the passed in
    # {Stomp::Message}
    #
    # @param [Stomp::Message] message A message created by the Stomp gem
    # @return [Stapfen::Message] A Stapfen wrapper object
    def self.from_stomp(message)
      unless message.kind_of? Stomp::Message
        raise Stapfen::InvalidMessageError, message.inspect
      end

      return self.new(:body => message.body,
                      :destination => message.headers['destination'],
                      :message_id => message.headers['message-id'],
                      :original => message)
    end

    # Create an instance of {Stapfen::Message} from the passed in
    # +ActiveMQBytesMessage+ which a JMS consumer should receive
    #
    # @param [ActiveMQBytesMessage] message
    # @return [Stapfen::Message] A Stapfen wrapper object
    def self.from_jms(message)
      unless message.kind_of? Java::JavaxJms::Message
        raise Stapfen::InvalidMessageError, message.inspect
      end

      return self.new(:body => message.data,
                      :destination => message.jms_destination.getQualifiedName,
                      :message_id => message.jms_message_id,
                      :original => message)
    end

    # Create an instance of {Stapfen::Message} from the passed in
    # +String+ which a Kafka consumer should receive
    #
    # @param [String] message
    # @return [Stapfen::Message] A Stapfen wrapper object
    def self.from_kafka(message)
      unless message.kind_of? String
        raise Stapfen::InvalidMessageError, message.inspect
      end

      return self.new(:body => message)
    end
  end
end
