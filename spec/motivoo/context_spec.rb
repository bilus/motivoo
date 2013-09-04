require 'spec_helper'
require 'motivoo/context'

module Motivoo
  describe Context do
    shared_examples_for "a context creation method" do
      it "should serialize tracker into env" do
        tracker.should_receive(:serialize_into).with(env).and_return(updated_env)
        action(env)
      end
      
      it "should create request based on modified env" do
        Rack::Request.should_receive(:new).with(updated_env).and_return(request)
        action(env)
      end

      it "should yield" do
        block = double("block")
        block.should_receive(:call)
        action(env) do
          block.call
          response
        end
      end
      
      it "should yield tracker and request" do
        action(env) do |arg1, arg2|
          arg1.should == tracker
          arg2.should == request
          response
        end
      end

      it "should finish response and return the result" do
        result = double("result")
        response.should_receive(:finish).and_return(result)
        action(env) { response }.should == result
      end
    end
    
    shared_examples_for "a context creation method for existing user" do
      let!(:connection) do 
        connection = double("connection")
        Connection.stub(:instance).and_return(connection)
        connection
      end
      
      let!(:tracker) do
        tracker = double("tracker")
        Tracker.stub(:new).and_return(tracker)
        tracker
      end
      
      let(:env) { double("env") }
      let(:updated_env) { double("updated_env") }
      
      let!(:request) do
        request = double("request")
        Rack::Request.stub(:new).and_return(request)
        request
      end
      
      let(:response) { double("response", finish: nil) }
      
      before(:each) do
        tracker.stub(:serialize_into).and_return(updated_env)
        user_data.stub(:serialize_into).and_return(response)
      end
      
      it "should get connection instance" do
        Connection.should_receive(:instance).and_return(connection)
        action(env)
      end
      
      it "should create tracker" do
        Tracker.should_receive(:new).with(user_data, connection, anything).and_return(tracker)
        action(env)
      end
      
      it "should inform tracker whether the user is an existing one" do
        Tracker.should_receive(:new).with(anything, anything, existing_user: is_existing_user).and_return(tracker)
        action(env)
      end

      it "should serialize user data to response" do
        user_data.should_receive(:serialize_into).with(response)
        action(env) do
          response
        end
      end

      it_should_behave_like "a context creation method"
    end
    
    describe "#create!" do
      def action(env, &block)
        Context.create!(env, &block)
      end

      let!(:user_data) do
        user_data = double("user_data")
        UserData.stub(:deserialize_from!).and_return([user_data, is_existing_user])
        user_data
      end
      
      let(:is_existing_user) { double("is_existing_user") }
      
      it_should_behave_like "a context creation method for existing user" do
        it "should deserialize user data" do
          UserData.should_receive(:deserialize_from!).with(env, connection).and_return([user_data, true])
          action(env)
        end
      end
    end

    describe "#create" do
      let(:tracker) { double("tracker", serialize_into: updated_env) }
      let(:env) { double("env") }
      let(:updated_env) { double("updated_env") }
      let(:user_data) { nil }
      let(:is_existing_user) { false }
      
      let!(:request) do
        request = double("request")
        Rack::Request.stub(:new).and_return(request)
        request
      end
      
      let(:response) { double("response", finish: nil) }
      
      def action(env, &block)
        Context.create(env, &block)
      end
   
      before(:each) do
        UserData.stub(:deserialize_from).and_return([user_data, is_existing_user])
      end
      
      context "given no existing user data" do
        let(:user_data) { double("user_data") }
        let(:is_existing_user) { false }

        before(:each) do
          NullTracker.stub(:instance).and_return(tracker)
        end
        
        it "should create a null tracker" do
          NullTracker.should_receive(:instance).and_return(tracker)
          action(env)
        end
        
        it "should not serialize user data" do
          user_data.should_not_receive(:serialize_into)
          action(env)
        end

        it_should_behave_like "a context creation method"
      end
      
      context "given existing user data" do
        let(:user_data) { {} }
        let(:is_existing_user) { true }
        it_should_behave_like "a context creation method for existing user"
      end
    end
  end
end