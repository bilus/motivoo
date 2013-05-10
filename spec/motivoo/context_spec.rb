require 'spec_helper'
require 'motivoo/context'

module Motivoo
  describe Context do
    context "when it is created" do
      let!(:connection) do 
        connection = mock("connection")
        Connection.stub!(:instance).and_return(connection)
        connection
      end
      
      let!(:user_data) do
        user_data = mock("user_data")
        UserData.stub!(:deserialize_from).and_return([user_data, true])
        user_data
      end
      
      let!(:tracker) do
        tracker = mock("tracker")
        Tracker.stub!(:new).and_return(tracker)
        tracker
      end
      
      let(:env) { double("env") }
      let(:updated_env) { double("updated_env") }
      
      let!(:request) do
        request = mock("request")
        Rack::Request.stub!(:new).and_return(request)
        request
      end
      
      let(:response) { double("response", finish: nil) }
      
      before(:each) do
        tracker.stub!(:serialize_into).and_return(updated_env)
        user_data.stub!(:serialize_into).and_return(response)
      end
      
      it "should get connection instance" do
        Connection.should_receive(:instance).and_return(connection)
        Context.create(env)
      end
      
      it "should deserialize user data" do
        UserData.should_receive(:deserialize_from).with(env, connection).and_return([user_data, true])
        Context.create(env)
      end
      
      it "should create tracker" do
        Tracker.should_receive(:new).with(user_data, connection, anything).and_return(tracker)
        Context.create(env)
      end
      
      it "should inform tracker whether the user is an existing one" do
        existing_user = double("existing_user_flag")
        UserData.stub!(:deserialize_from).and_return([user_data, existing_user])
        Tracker.should_receive(:new).with(anything, anything, existing_user: existing_user).and_return(tracker)
        Context.create(env)
      end
      
      it "should serialize it into env" do
        tracker.should_receive(:serialize_into).with(env).and_return(updated_env)
        Context.create(env)
      end
      
      it "should create request based on modified env" do
        Rack::Request.should_receive(:new).with(updated_env).and_return(request)
        Context.create(env)
      end

      it "should yield" do
        block = mock("block")
        block.should_receive(:call)
        Context.create(env) do
          block.call
          response
        end
      end
      
      it "should yield tracker and request" do
        Context.create(env) do |arg1, arg2|
          arg1.should == tracker
          arg2.should == request
          response
        end
      end
      
      it "should serialize user data to response" do
        user_data.should_receive(:serialize_into).with(response)
        Context.create(env) do
          response
        end
      end
      
      it "should finish response and return the result" do
        result = double("result")
        response.should_receive(:finish).and_return(result)
        Context.create(env) { response }.should == result
      end
    end
  end
end