require 'spec_helper'
require 'stapfen/destination'

describe Stapfen::Destination do
  it { should respond_to :name }
  it { should respond_to :type }

  describe '#as_kafka' do
    let(:name) { 'topic' }
    subject(:destination) do
      d = described_class.new
      d.type = :topic
      d.name = name
      d.as_kafka
    end

    it { should be_instance_of String }
    it { should eql "topic" }
  end

  describe '#as_jms' do
    let(:name) { 'rspec/dlq' }
    subject(:destination) do
      d = described_class.new
      d.type = :queue
      d.name = name
      d.as_jms
    end

    it { should be_instance_of String }
    it { should eql "queue://#{name}" }
  end

  describe '#as_stomp' do
    let(:name) { 'rspec/dlq' }

    subject(:destination) do
      d = described_class.new
      d.type = :queue
      d.name = name
      d.as_stomp
    end

    it { should be_instance_of String }
    it { should eql "/queue/#{name}" }
  end

  context 'class methods' do
    describe '#from_string' do
      subject(:destination) { described_class.from_string(name) }

      context 'a simple queue' do
        let(:name) { '/queue/rspec' }
        its(:name) { should eql 'rspec' }
        its(:type) { should eql :queue }
      end

      context 'a queue with slashes' do
        let(:name) { '/queue/rspec/dlq' }
        its(:name) { should eql 'rspec/dlq' }
        its(:type) { should eql :queue }
      end

      context 'a complex topic' do
        let(:name) { '/topic/rspec/dlq' }
        its(:name) { should eql 'rspec/dlq' }
        its(:type) { should eql :topic }
      end
    end
  end
end
