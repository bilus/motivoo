require 'spec_helper'
require 'motivoo/context'

module Motivoo
  describe Context do
    describe "#create" do
      let(:env) { double("env") }
      let(:updated_env) { double("updated_env") }
      
      let!(:request) do
        request = double("request", cookies: nil)
        Rack::Request.stub(:new).and_return(request)
        request
      end
      
      let(:response) { double("response", finish: nil) }
      let(:tracker) { double("tracker", serialize_into: updated_env, ensure_assigned_to_cohorts: nil) }
      let(:tracker_class) { proc { double("tracker_type", new: tracker) } }

      let!(:user_data) do 
        user_data = double("user_data", serialize_into: nil) 
        UserData.stub(:deserialize_from!).and_return([user_data, is_existing_user])
        user_data
      end
      let(:is_existing_user) { double("is_existing_user") }

      let!(:connection) do 
        connection = double("connection")
        Connection.stub(:instance).and_return(connection)
        connection
      end
      
      def create_context(env, &block)
        Context.create(env, tracker_class, &block)
      end
      
      it "should serialize tracker into env" do
        # tracker.should_receive(:serialize_into).with(env).and_return(updated_env)
        create_context(env)
      end
      
      it "should create request based on modified env" do
        Rack::Request.should_receive(:new).with(updated_env).and_return(request)
        create_context(env)
      end

      it "should yield" do
        block = double("block")
        block.should_receive(:call)
        create_context(env) do
          block.call
          response
        end
      end
      
      it "should yield tracker and request" do
        create_context(env) do |arg1, arg2|
          arg1.should == tracker
          arg2.should == request
          response
        end
      end

      it "should finish response and return the result" do
        result = double("result")
        response.should_receive(:finish).and_return(result)
        create_context(env) { response }.should == result
      end

      it "should get connection instance" do
        Connection.should_receive(:instance).and_return(connection)
        create_context(env)
      end
      
      it "should ask tracker to assign user to cohorts" do
        tracker.should_receive(:ensure_assigned_to_cohorts)
        create_context(env)
      end

      it "should serialize user data to response" do
        user_data.should_receive(:serialize_into).with(response)
        create_context(env) do
          response
        end
      end

      it "should deserialize user data" do
        UserData.should_receive(:deserialize_from!).with(env, connection).and_return([user_data, true])
        create_context(env)
      end
    end
  end
end