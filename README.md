# Stapfen


Stapfen is a simple gem to make writing workers that consume messages via
[STOMP](http://stomp.github.io/) or
[JMS](https://en.wikipedia.org/wiki/Java_Message_Service) easier.

Stapfen allows you to write one worker class, and use either protocol
depending on the environment and needs.


**[RDoc here](http://rdoc.info/github/lookout/stapfen/master/frames)**

## Usage

(Examples can be found in the `examples/` directory)


Consider the following `myworker.rb` file:

```ruby
class MyWorker < Stapfen::Worker
  configure do |worker|
    # You can also specify your own logger, but this is the default...
    worker.logger = Logger.new(STDOUT)
    worker.protocol = STOMP
    worker.client_options = {
      :hosts => [
        {
          :host => 'localhost',
          :port => 61613,
          :login => 'guest',
          :passcode => 'guest',
          :ssl => false
        }
      ],
      :topic => 'thequeue',
      :dead_letter_queue => '/queue/dlq',
      :max_redeliveries => 0
    }
  end

  consume do |message|
    data = expensive_computation(message.body)
    # Save my data, or do something worker-specific with it
    persist(data)

    # Send another message
    client.publish('/topic/computation-acks', "finished with #{message.message_id}")
  end

end

MyWorker.run!
```

When using the STOMP protocol, `worker.client_options` can be set with any of the attributes described in a `Stomp::Client` [connection
hash](https://github.com/stompgem/stomp#hash-login-example-usage-this-is-the-recommended-login-technique) as well as any `subscription` options.

When using the JMS protocol, `worker.client_options` can be set with any of the attributes described in [configuration
hash](https://github.com/reidmorrison/jruby-jms#consumer) for the
[jruby-jms](https://github.com/reidmorrison/jruby-jms) gem.

#### Kafka example

Using with Kafka requires a configuration with the topic, groupID, and zookeepers string.

```ruby
require 'stapfen'
require 'stapfen/worker'

class MyWorker < Stapfen::Worker
  configure do |worker|
    # You can also specify your own logger, but this is the default...
    worker.logger = Logger.new(STDOUT)
    worker.protocol = KAFKA
    worker.client_options = {
      :topic => 'test',
      :groupId => 'groupId',
      :zookeepers => 'localhost:2181' # comma separated string of zookeepers
    }
  end

  consume do |message|
    puts "Recv: #{message.body}"
  end
end

MyWorker.run!
```

##### Notes
* Testing with Kafka
  * Start Staphen worker first
  * Using producer included with kafka
    * Produce some messages
      * ```echo foobar | bin/kafka-console-producer.sh --broker-list <brokers> --topic <topic>```
    * Worker should be able to read the message
* using the same groupId a consumer will start reading from the last offset that was read by a consumer from the same group
  * For example, Given 2 consumers belong to the same groupId
    * Consumer1 reads a few messages and dies
    * A producer produces 5 messages
    * Consumer2 starts up and will receive the 5 messages produced because it started at the last offset of Consumer1

---

It is also important to note that the `consume` block will be invoked inside an
**instance** of `MyWorker` and will execute inside its own `Thread`, so take
care when accessing other shared resources.

Also note you'll need to include the zk gem manually.

### Fallback and dead-letter-queue support

The consume block accepts the usual subscriptions headers, as well as two
additional headers `:dead_letter_queue` and `:max_redeliveries`.  If either of
the latter two is present, the consumer will unreceive any messages for which
the block returns `false`; after `:max_redeliveries`, it will send the message
to `:dead_letter_queue`.  `consume` blocks without these headers will fail
silently rather than unreceive.

## Installation

Add this line to your application's Gemfile:

    gem 'stapfen'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install stapfen

## Running Specs

Download this from jar from Maven Central
  * [activemq-all-5.8.0.jar](http://search.maven.org/#artifactdetails%7Corg.apache.activemq%7Cactivemq-all%7C5.8.0%7Cjar)
  * `wget -O activemq-all-5.8.0.jar http://search.maven.org/remotecontent?filepath=org/apache/activemq/activemq-all/5.8.0/activemq-all-5.8.0.jar`
  * Put it in gem root
  * ```rake spec```

