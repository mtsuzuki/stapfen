require 'spec_helper'

describe Stapfen::Logger do
  let(:mixin) do
    Class.new do
      include Stapfen::Logger
    end
  end

  subject(:logger) { mixin.new }

  context 'instance methods' do
    it { should respond_to :info }
    it { should respond_to :debug }
    it { should respond_to :warn }
    it { should respond_to :error }

    context 'without an initialized logger' do
      before :each do
        logger.class.stub(:logger)
      end

      it 'should discard info messages' do
        expect(logger.info('rspec')).to be false
      end
    end

    context 'with an initialized logger' do
      let(:plogger) { double('RSpec Logger') }

      before :each do
        logger.class.stub(:logger).and_return(lambda { plogger })
      end

      it 'should pass info messages along' do
        plogger.should_receive(:info)
        expect(logger.info('rspec')).to be true
      end
    end
  end
end
