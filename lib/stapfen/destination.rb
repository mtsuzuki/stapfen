module Stapfen
  class Destination
    attr_accessor :name, :type

    def queue?
      @type == :queue
    end

    def topic?
      @type == :topic
    end

    def as_stomp
      if queue?
        return "/queue/#{@name}"
      end

      if topic?
        return "/topic/#{@name}"
      end
    end

    def as_jms
      if queue?
        return "queue://#{@name}"
      end

      if topic?
        return "topic://#{@name}"
      end
    end

    def jms_opts
      if queue?
        return {:queue_name => name}
      end

      if topic?
        return {:topic_name => name}
      end
    end

    def as_kafka
      return name
    end

    # Create a {Stapfen::Destination} from the given string
    #
    # @param [String] name
    # @return [Stapfen::Destination]
    def self.from_string(name)
      destination = self.new
      pieces = name.split('/')
      destination.type = pieces[1].to_sym
      destination.name = pieces[2 .. -1].join('/')
      return destination
    end
  end
end
