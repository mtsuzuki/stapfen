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
  use_stomp!

  configure do
    {
      :hosts => [
        {
          :host => 'localhost',
          :port => 61613,
          :login => 'guest',
          :passcode => 'guest',
          :ssl => false
        }
      ]
    }
  end

  # [Optional] Set up a logger for each worker instance
  log do
    Logger.new(STDOUT)
  end

  consume 'thequeue', :dead_letter_queue => '/queue/dlq',
                      :max_redeliveries => 0 do |message|

    data = expensive_computation(message.body)
    # Save my data, or do something worker-specific with it
    persist(data)

    # Send another message
    client.publish('/topic/computation-acks', "finished with #{message.message_id}")
  end

end

MyWorker.run!
```


When using the STOMP protocol, the value returned from the `configure` block is expected to be a valid
`Stomp::Client` [connection
hash](https://github.com/stompgem/stomp#hash-login-example-usage-this-is-the-recommended-login-technique).

In the case of the JMS protocol, the value returned from the `configure` block
is expected to be a valid [configuration
hash](https://github.com/reidmorrison/jruby-jms#consumer) for the
[jruby-jms](https://github.com/reidmorrison/jruby-jms) gem.

---

It is also important to note that the `consume` block will be invoked inside an
**instance** of `MyWorker` and will execute inside its own `Thread`, so take
care when accessing other shared resources.

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

