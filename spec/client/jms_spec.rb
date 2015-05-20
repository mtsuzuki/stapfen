require 'spec_helper'

if RUBY_PLATFORM == 'java'
  require 'stapfen/client/jms'

  describe Stapfen::Client::JMS, :java => true do
    let(:config) { {} }
    subject(:client) { described_class.new(config) }

    it { should respond_to :connect }

    describe '#can_unreceive?' do
      subject { client.can_unreceive? }

      it { should be true }
    end

    describe '#unreceive' do
      let(:body) { 'Some body in string form' }
      let(:message) { double('Message', :destination => orig_destination, :data => body, :getStringProperty => nil) }
      let(:max_redeliveries) { 2 }
      let(:dlq) { '/queue/some_queue/dlq' }

      let(:orig_destination) { '/queue/some_queue' }

      subject(:unreceive!) { client.unreceive(message, unreceive_headers) }

      context 'with no unreceive[:dead_letter_queue] and no unreceive[:max_redeliveries]' do
        let(:unreceive_headers) { Hash.new }
        it 'should not resend the message' do
          client.should_not_receive(:publish)
          unreceive!
        end
      end

      context 'with no unreceive[:max_redeliveries]' do
        let(:unreceive_headers) do
          { dead_letter_queue: '/queue/some_queue/dlq' }
        end

        it 'should resend the message' do
          client.should_receive(:publish) do |dest, the_body, the_headers|
            expect(dest).to eql '/queue/some_queue/dlq'
          end
          unreceive!
        end
      end

      context 'with no unreceive[:dead_letter_queue]' do
        let(:unreceive_headers) { { max_redeliveries: 2 } }

        it 'should resend the message' do
          client.should_receive(:publish) do |dest, the_body, the_headers|
            expect(dest).to eql orig_destination
            expect(the_body).to eql body
          end

          unreceive!
        end
      end

      let(:unreceive_headers) do
        { :dead_letter_queue => dlq, :max_redeliveries => max_redeliveries }
      end

      context 'On a message with no retry_count in the headers' do
        before :each do
          message.stub(:getStringProperty).with('retry_count').and_return(nil)
        end

        it 'should publish it to the same destination with a retry_count of 1' do
          client.should_receive(:publish) do |dest, the_body, the_headers|
            expect(dest).to eql orig_destination
            expect(the_body).to eql body
            expect(the_headers).to eql({'retry_count' => '1'})
          end

          unreceive!
        end
      end

      context 'On a message with a retry_count in the headers' do
        before :each do
          message.stub(:getStringProperty).with('retry_count').and_return(retry_count)
        end


        context 'that is less than max_redeliveries' do
         let(:retry_count) { max_redeliveries - 1 }
          it 'should publish it to the same destination with a retry_count increased by one' do
            client.should_receive(:publish) do |dest, the_body, the_headers|
              expect(dest).to eql orig_destination
              expect(the_body).to eql body
              expect(the_headers).to eql({'retry_count' => (retry_count + 1).to_s})
            end

            unreceive!
          end
        end

        # This is the 'last' attempt to redeliver, so don't send it again
        context 'that is equal to max_redeliveries' do
         let(:retry_count) { max_redeliveries }

          it 'should publish it to the DLQ with no retry_count' do
            client.should_receive(:publish) do |dest, the_body, the_headers|
              expect(the_body).to eql body
              expect(dest).to eql dlq
              expect(the_headers).to eql({:original_destination => orig_destination})
            end

            unreceive!
          end
        end

        context 'that is greater than max_redeliveries' do
         let(:retry_count) { max_redeliveries + 1 }

          it 'should publish it to the DLQ with no retry_count' do
            client.should_receive(:publish) do |dest, the_body, the_headers|
              expect(the_body).to eql body
              expect(dest).to eql dlq

              expect(the_headers).to eql({:original_destination => orig_destination})
            end

            unreceive!
          end
        end

        context 'with a topic url destination' do
          let(:retry_count) { max_redeliveries + 1 }
          let(:orig_destination) { 'topic://some_queue' }
          it 'should succeed' do
            client.should_receive(:publish) do |dest, the_body, the_headers|
              expect(the_body).to eql body
              expect(dest).to eql dlq
              expect(the_headers).to eql({:original_destination => '/topic/some_queue'})
            end
            unreceive!
          end
        end

        context 'with a queue url destination' do
          let(:retry_count) { max_redeliveries + 1 }
          let(:orig_destination) { 'queue://some_queue' }
          it 'should succeed' do
            client.should_receive(:publish) do |dest, the_body, the_headers|
              expect(the_body).to eql body
              expect(dest).to eql dlq
              expect(the_headers).to eql({:original_destination => '/queue/some_queue'})
            end
            unreceive!
          end
        end
      end
    end

    describe '#connect' do
      subject(:connection) { client.connect }
      let(:jms_conn) { double('JMS::Connection') }

      before :each do
        ::JMS::Connection.should_receive(:new).and_return(jms_conn)
      end

      it 'should start the connection' do
        jms_conn.should_receive(:start)
        expect(connection).to eql(jms_conn)
      end
    end

    describe '#session' do
      let(:session) { double('JMS::Session') }
      let(:connection) { double('JMS::Connection') }

      before :each do
        client.stub(:connection => connection)
      end

      context 'without a session already' do
        it 'should create a new session' do
          connection.should_receive(:create_session).and_return(session)
          expect(client.session).to eql(session)
        end
      end

      context 'with an existing session' do
        it 'should return that existing session' do
          connection.should_receive(:create_session).once.and_return(session)
          3.times do
            expect(client.session).to eql(session)
          end
        end
      end
    end

    describe '#publish' do
    end

    describe '#closed?' do
      subject(:result) { client.closed? }

      context 'if a connection exists' do
        before :each do
          client.stub(:connection).and_return(double('JMS::Connection'))
        end

        it { should be false }
      end

      context 'without a connection' do
        it { should be true }
      end
    end

    describe '#close' do
      subject(:result) { client.close }
      let(:connection) { double('JMS::Connection') }

      before :each do
        client.instance_variable_set(:@connection, connection)
      end

      context 'without an existing session' do
        it 'should close the client' do
          connection.should_receive(:close)
          expect(result).to be true
        end
      end

      context 'with an existing session' do
        let(:session) { double('JMS::Session') }

        before :each do
          client.instance_variable_set(:@session, session)
        end

        it 'should close the client and session' do
          session.should_receive(:close)
          connection.should_receive(:close)
          expect(result).to be true
        end
      end
    end
  end
end
