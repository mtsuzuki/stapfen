$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))
require 'stapfen'
require ENV['activemq_jar'] if ENV['USE_JMS']


class Worker < Stapfen::Worker

  configure do
    {:hosts => [
      {
        :host => 'localhost',
        :port => 61613,
        :login => 'guest',
        :passcode => 'guest',
        :ssl => false
      }
    ],
    :factory => 'org.apache.activemq.ActiveMQConnectionFactory'}
  end

  use_jms! if ENV['USE_JMS']

  if ENV['USE_JMS']
    consume '/queue/jms.queue.test',
            :max_redeliveries => 3,
            :dead_letter_queue => '/queue/jms.queue.test/dlq' do |message|
      puts "received: #{message}"

      # False here forces an unreceive
      return false
    end
  else # use stomp
    consume '/queue/test',
            :max_redeliveries => 3,
            :dead_letter_queue => '/queue/test/dlq' do |message|
      puts "received: #{message}"

      # False here forces an unreceive
      return false
    end
  end
end

Worker.run!
