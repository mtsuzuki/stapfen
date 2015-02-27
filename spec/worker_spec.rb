require 'spec_helper'
require 'stapfen/client/stomp'

class ExampleWorker < Stapfen::Worker
end

# `exit` is private in 1.9.3 so this is a little hack to add the
# namespace for java and make that `exit` method public. Since we use
# it in our tests below.
module Java
  module JavaLang
    class System
      class << self
        public :exit
      end
    end
  end
end

describe Stapfen::Worker do

  after(:each) do
    # These variables will persist between tests unless they're
    # explicitly cleared. Also see `set_class_variable_defaults`.
    described_class.set_class_variable_defaults
    described_class.consumers = nil
    if described_class.const_defined?(:RUBY_PLATFORM, false)
      described_class.send(:remove_const, :RUBY_PLATFORM)
    end
  end

  describe '.configure' do
    let(:dummy_proc) { Proc.new { double('Proc') } }
    let(:example_logger) { double('Logger') }
    let(:example_protocol) { double('Protocol') }
    let(:example_connection_options) { double('Connection Options') }

    it 'accepts a configuration block' do
      ExampleWorker.configure &dummy_proc
      expect(ExampleWorker.instance_configuration).to eq(dummy_proc)
    end
  end

  describe '.run!' do
    let(:dummy_instance) { double('Instance') }
    it 'creates a new instance, handle signals, and call run' do
      expect(ExampleWorker).to receive(:new).and_return dummy_instance
      expect(ExampleWorker).to receive(:handle_signals)
      expect(dummy_instance).to receive(:run)

      ExampleWorker.run!

      expect(ExampleWorker.class_variable_get(:@@workers)).to eq [dummy_instance]
    end
  end

  describe '.consume(config_overrides={}, &block)' do
    it 'adds the given block and config to @consumers array' do
      example_proc = Proc.new {}
      example_hash = double('hash')
      described_class.consume(example_hash, &example_proc)
      expect(described_class.consumers.first).to be_an(Array)
      expect(described_class.consumers.first.first).to be example_hash
      expect(described_class.consumers.first.last).to be example_proc
    end

    it 'raises a Stapfen::ConsumeError when called without a block' do
      expect { described_class.consume }.to raise_error(Stapfen::ConsumeError)
    end
  end

  describe '.shutdown(&block)' do
    it 'sets @destructor' do
      example_proc = Proc.new {}
      described_class.shutdown &example_proc
      expect(described_class.instance_variable_get(:@destructor)).to be(example_proc)
    end
  end

  describe '.workers' do
    it 'returns the array of workers' do
      expect(described_class.workers).to eq([])
    end
  end

  describe '.exit_cleanly' do
    let(:example_worker) { double('ExWorker') }

    it 'is false if no workers' do
      expect(described_class.workers.empty?).to eq(true)
      expect(described_class.exit_cleanly).to eq(false)
    end

    it 'cleanly exits the worker and java environment' do
      described_class.const_set(:RUBY_PLATFORM, 'java')
      described_class.workers << example_worker
      expect(Java::JavaLang::System).to receive(:exit).with(0)
      expect(example_worker).to receive(:exit_cleanly)
      expect(described_class.exit_cleanly).to eq(true)
    end

    it 'cleanly exits just the worker when not java' do
      described_class.const_set(:RUBY_PLATFORM, '*not java*')
      described_class.workers << example_worker
      expect(Java::JavaLang::System).to_not receive(:exit)
      expect(example_worker).to receive(:exit_cleanly)
      expect(described_class.exit_cleanly).to eq(true)
    end

    it 'is false if an exception is raised' do
      described_class.const_set(:RUBY_PLATFORM, 'java')
      expect(Java::JavaLang::System).to receive(:exit).with(0)
      described_class.workers << example_worker
      expect(example_worker).to receive(:exit_cleanly).and_raise(StandardError)
      expect(described_class.exit_cleanly).to eq(false)
    end
  end

  describe '.handle_signals' do
    it 'traps INT and TERM' do
      expect(Signal).to receive(:trap).with(:INT)
      expect(Signal).to receive(:trap).with(:TERM)
      described_class.handle_signals
    end
  end

  describe '#use_stomp!' do
    it 'should require stomp' do
      expect(subject).to receive(:require).with('stomp')
      subject.use_stomp!
      expect(subject.instance_variable_get(:@protocol)).to eq Stapfen::Worker::STOMP
    end

    it 'should raise a LoadError if require fails' do
      expect(subject).to receive(:require).and_raise(LoadError)
      expect { subject.use_stomp! }.to raise_error(LoadError)
    end
  end

  describe '#stomp?' do
    it 'is true when the protocol is stomp' do
      subject.protocol = Stapfen::Worker::STOMP
      expect(subject.stomp?).to be(true)
    end

    it 'is false when the protocol is anything else' do
      subject.protocol = Stapfen::Worker::JMS
      expect(subject.stomp?).to be(false)
    end
  end

  describe '#use_jms!' do
    it 'should require jms' do
      described_class.const_set(:RUBY_PLATFORM, 'java')
      expect(subject).to receive(:require).with('java')
      expect(subject).to receive(:require).with('jms')
      subject.use_jms!
      expect(subject.instance_variable_get(:@protocol)).to eq Stapfen::Worker::JMS
    end

    it 'should raise a Stapfen::ConfigurationError if require fails' do
      described_class.const_set(:RUBY_PLATFORM, '*not java*')
      expect { subject.use_jms! }.to raise_error(Stapfen::ConfigurationError)
    end

    it 'should raise a LoadError if require fails' do
      described_class.const_set(:RUBY_PLATFORM, 'java')
      expect(subject).to receive(:require).and_raise(LoadError)
      expect { subject.use_jms! }.to raise_error(LoadError)
    end
  end

  describe '#jms?' do
    it 'is true when the protocol is jms' do
      subject.protocol = Stapfen::Worker::JMS
      expect(subject.jms?).to be(true)
    end

    it 'is false when the protocol is anything else' do
      subject.protocol = Stapfen::Worker::STOMP
      expect(subject.jms?).to be(false)
    end
  end

  describe '#use_kafka!' do
    it 'should require kafka' do
      described_class.const_set(:RUBY_PLATFORM, 'java')
      expect(subject).to receive(:require).with('java')
      expect(subject).to receive(:require).with('hermann')
      subject.use_kafka!
      expect(subject.instance_variable_get(:@protocol)).to eq Stapfen::Worker::KAFKA
    end

    it 'should raise a Stapfen::ConfigurationError if require fails' do
      described_class.const_set(:RUBY_PLATFORM, '*not java*')
      expect { subject.use_kafka! }.to raise_error(Stapfen::ConfigurationError)
    end

    it 'should raise a LoadError if require fails' do
      described_class.const_set(:RUBY_PLATFORM, 'java')
      expect(subject).to receive(:require).and_raise(LoadError)
      expect { subject.use_kafka! }.to raise_error(LoadError)
    end
  end

  describe '#kafka?' do
    it 'is true when the protocol is kafka' do
      subject.protocol = Stapfen::Worker::KAFKA
      expect(subject.kafka?).to be(true)
    end

    it 'is false when the protocol is anything else' do
      subject.protocol = Stapfen::Worker::JMS
      expect(subject.kafka?).to be(false)
    end
  end

  describe '#exit_cleanly' do
    let(:stapfen_client) { double('RSpec Stomp Client') }

    before :each do
      subject.stub(:stapfen_client).and_return(stapfen_client)
    end

    it 'should close the stapfen_client' do
      stapfen_client.stub(:closed?).and_return(false)
      stapfen_client.should_receive(:close)
      subject.exit_cleanly
    end

    context 'with out having connected a stapfen_client yet' do
      before :each do
        subject.stub(:stapfen_client).and_return(nil)
      end

      it 'should not raise any errors' do
        expect {
          subject.exit_cleanly
        }.not_to raise_error
      end
    end
  end

  describe '.configure' do
    let(:config_proc) { Proc.new { {:valid => true} } }
    it 'should error when not passed a block' do
      expect {
        described_class.configure
      }.to raise_error(Stapfen::ConfigurationError)
    end

    it 'should save the return value from the block' do
      described_class.configure &config_proc
      expect(described_class.instance_configuration.call).to eql(config_proc.call)
    end
  end

  describe '.exit_cleanly', :java => true do
    subject(:result) { described_class.exit_cleanly }

    before do
      allow(Java::JavaLang::System).to receive(:exit).with(0)
    end

    after do
      described_class.class_variable_set(:@@workers, [])
    end

    context 'with no worker classes' do
      it { should be false }
    end

    context 'with a single worker class' do
      let(:w) { double('Fake worker instance') }

      before :each do
        described_class.class_variable_set(:@@workers, [w])
      end

      it "should execute the worker's .exit_cleanly method" do
        w.should_receive(:exit_cleanly)
        expect(result).to be true
      end

      it "should return false if the worker's .exit_cleanly method" do
        w.should_receive(:exit_cleanly).and_raise(StandardError)
        expect(result).to be false
      end
    end

    context 'with multiple worker classes' do
      let(:w1) { double('Fake Worker 1') }
      let(:w2) { double('Fake Worker 2') }

      before do
        described_class.class_variable_set(:@@workers, [w1, w2])
      end

      it 'should invoke both .exit_cleanly methods' do
        expect(w1).to receive(:exit_cleanly)
        expect(w2).to receive(:exit_cleanly)
        expect(described_class.exit_cleanly).to be true
      end
    end
  end

  describe 'detailed consume tests' do
    context 'if no block is passed' do
      it 'should raise an error if no block is passed' do
        expect {
          described_class.consume 'jms.queue.lol'
        }.to raise_error(Stapfen::ConsumeError)
      end
    end

    context 'with just a queue name' do
      let(:name) { 'jms.queue.lol' }
      let(:client_options) { {:topic => name} }

      before do
        described_class.instance_variable_set(:@consumers, [])
      end

      it 'should add an entry for the queue name' do
        described_class.consume(client_options) do |msg|
          nil
        end

        described_class.consumers.should_not be_empty
        entry = described_class.consumers.first
        entry.first.should eq(client_options)
      end
    end

    context 'unreceive behavior' do
      let(:stapfen_client) do
        c = double('Mock Stapfen::Client')
        c.stub(:connect)
        c.stub(:can_unreceive? => true)
        c.stub(:runloop)
        c.stub(:unreceive)
        c
      end

      let(:name) { '/queue/some_queue' }
      let(:client_options) { {:topic => name} }
      let(:message) do
        m = Stomp::Message.new(nil)
        m.stub(:body => 'rspec msg')
        m
      end

      before :each do
        Stapfen::Client::Stomp.stub(:new).and_return(stapfen_client)

        # Clear any old consumers out
        described_class.consumers = []

        # Get a subscription?  Call the message handler block.
        stapfen_client.stub(:subscribe) do |name, headers, &block|
          block.call(message)
        end

        config = {:valid => true}

        described_class.configure do
          config
        end
      end

      after do
        described_class.class_variable_set(:@@workers, [])
      end

      context 'using stomp' do
        before do
          described_class.configure do |w|
            w.use_stomp!
          end
        end

        context 'with just a queue name' do
          context 'on a failed message' do
            it 'should not unreceive' do
              stapfen_client.should_receive(:unreceive).never

              described_class.consume(client_options) {|msg| false }
              described_class.new.run
            end
          end
          context 'on a successful message' do
            it 'should not unreceive' do
              stapfen_client.should_receive(:unreceive).never

              described_class.consume(client_options) {|msg| true }
              described_class.new.run
            end
          end
        end

        context 'with a queue name and headers for a dead_letter_queue and max_redeliveries' do
          let(:unrec_headers) do
            { :dead_letter_queue => '/queue/foo',
            :max_redeliveries => 3 }
          end

          let(:raw_headers) { unrec_headers.merge(:other_header => 'foo!') }
          let(:client_options) { {:topic => name}.merge(raw_headers) }
          let(:config_overrides) { client_options.merge(unrec_headers) }
          context 'on a failed message' do
            it 'should unreceive' do
              stapfen_client.should_receive(:unreceive).once

              described_class.consume(config_overrides) {|msg| false }
              described_class.new.run
            end
            it 'should pass :unreceive_headers through to the unreceive call' do
              stapfen_client.should_receive(:unreceive).with(message, config_overrides).once

              described_class.consume(config_overrides) {|msg| false }
              described_class.new.run
            end
            it 'should not remove the unreceive headers from the consumer' do
              described_class.consume(config_overrides) {|msg| false}
              described_class.new.run

              expect(described_class.consumers.last[0][:dead_letter_queue]).to eql unrec_headers[:dead_letter_queue]
              expect(described_class.consumers.last[0][:max_redeliveries]).to eql unrec_headers[:max_redeliveries]
            end
          end
          context 'on a successfully handled message' do
            it 'should not unreceive' do
              stapfen_client.should_receive(:unreceive).never

              described_class.consume(config_overrides) {|msg| true }
              described_class.new.run
            end
          end
        end
      end
    end
  end
end
