require 'spec_helper'
require 'stapfen/client/kafka'


describe Stapfen::Client::Kafka, :java => true do
  let(:config)           { { :topic => 'test', :groupId => 'groupId', :zookeepers => 'foo' } }
  let(:consumer)         { double('Hermann::Consumer') }

  subject(:client) { described_class.new(config) }

  before do
    allow(Hermann::Consumer).to receive(:new) { consumer }
  end

  it { should respond_to :connect }

  describe '#initialize' do
    context 'with valid input params' do
      let(:hermann_opts)     { { :do_retry => false } }
      let(:opts)             { { :consumer_opts => hermann_opts } }
      let(:config_with_opts) { config.merge(opts) }

      subject(:client) { described_class.new(config_with_opts) }

      it 'should be a object' do
        expect(Hermann::Consumer).to receive(:new).with(
          config[:topic],
          config[:groupId],
          config[:zookeepers],
          hermann_opts)
        expect(client).to be_a described_class
      end
    end

    context 'without valid input params' do
      let(:config) { {} }
      it 'should raise error' do
        expect{ client }.to raise_error(Stapfen::ConfigurationError)
      end
    end
  end

  describe '#can_unreceive?' do
    subject { client.can_unreceive? }
    it { should be false }
  end

  describe '#close' do
    subject(:result) { client.close }

    context 'with a connection' do
      it 'should close the client' do
        allow(consumer).to receive(:shutdown)
        expect(result).to be true
      end
    end
    context 'without a connection' do
      it 'returns false' do
        expect(Hermann::Consumer).to receive(:new) { nil }
        expect(consumer).to_not receive(:shutdown)
        expect(result).to be false
      end
    end
  end

  describe '#closed?' do
    subject(:result) { client.closed? }

    context 'if a connection exists' do
      before :each do
        allow(client).to receive(:connection) { double('KAFKA::Connection') }
      end
      it { should be false }
    end

    context 'without a connection' do
      before :each do
        allow(client).to receive(:connection) { nil }
      end
      it { should be true }
    end
  end

  describe '#subscribe' do
    let(:topic) { 'topic' }
    let(:msg) { 'foo' }
    it 'yields to the block and passes in consumed message' do
      allow(consumer).to receive(:consume).with(topic).and_yield(msg)

      expect{ |b|
        client.subscribe(topic, nil, &b)
      }.to yield_with_args(msg)
    end
  end
end
