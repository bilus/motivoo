require 'spec_helper'
require 'motivoo/user_data'

module Motivoo
  describe UserData do
    let(:connection) { mock("connection").as_null_object }
    let(:env_no_user_id) { {"HTTP_COOKIE" => ""} }

    let(:user_id) { "user_id" }
    let(:env_with_user_id) { {"HTTP_COOKIE" => "#{UserData::USER_ID_COOKIE}=#{user_id}"} }
    let(:cohorts) { {"month" => "2012-10"} }
    let(:user_data) { {"cohorts" => cohorts} }

    let(:response) { mock("response") }
    
    context "when deserializing from env" do
      it "should find or create user data if user id is in cookies" do
        connection.should_receive(:find_or_create_user_data).with(user_id).and_return(user_data)
        user_data = UserData.deserialize_from(env_with_user_id, connection)
        user_data.cohorts.should == cohorts
      end
      
      it "should create user data set if no user id" do
        connection.should_receive(:generate_user_id).and_return(user_id)
        user_data = UserData.deserialize_from(env_no_user_id, connection)
        user_data.cohorts.should == {}
      end
    end

    context "when serializing into response" do
      let(:new_user_id) { "new_user_id" }

      it "should generate a new user id if user id wasn't in cookies" do
        connection.stub!(:generate_user_id).and_return(new_user_id)
        user_data = UserData.deserialize_from(env_no_user_id, connection)
        response.should_receive(:set_cookie).with(anything, new_user_id)
        user_data.serialize_into(response)
      end
      
      it "should set user id cookie if it was" do
        user_data = UserData.deserialize_from(env_with_user_id, connection)
        response.should_receive(:set_cookie).with(anything, user_id)
        user_data.serialize_into(response)
      end
    end
    
    context "when assigning to cohort" do
      let(:cohort_name) { "cohort_name" }
      let(:cohort) { "cohort" }
      let(:user_data) { UserData.new(user_id, {}, connection)}
      
      it "should update the database" do
        connection.should_receive(:assign_cohort).with(user_id, cohort_name, cohort)
        user_data.assign_to(cohort_name, cohort)
      end
      
      it "should make local changes" do
        user_data.assign_to(cohort_name, cohort)
        user_data.cohorts[cohort_name].should == cohort
      end
    end
  end
end