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
    
    context "when external user id is set" do
      let(:ext_user_id) { "ext_user_id" }
      let!(:user_data) do
        connection.stub!(:find_or_create_user_data).and_return({})
        UserData.deserialize_from(env_with_user_id, connection)
      end
      let(:new_user_id) { "new_user_id" }
      let(:user_data_hash) { {"cohorts" => cohorts} }
      
      it "should find existing user data record by external user id" do
        connection.should_receive(:find_user_data_by_ext_user_id).with(ext_user_id).and_return([new_user_id, user_data_hash])
        user_data.set_ext_user_id(ext_user_id)
      end
      
      context "if record found" do
        before(:each) do
          connection.stub!(:find_user_data_by_ext_user_id).and_return([new_user_id, user_data_hash])
        end
      
        it "should delete obsolete user data record" do
          connection.should_receive(:destroy_user_data).with(user_id)
          user_data.set_ext_user_id(ext_user_id)
        end

        it "should then serialize new user id" do
          user_data.set_ext_user_id(ext_user_id)
          response.should_receive(:set_cookie).with(anything, new_user_id)
          user_data.serialize_into(response)
        end
      
        it "should set cohorts" do
          user_data.set_ext_user_id(ext_user_id)
          user_data.cohorts.should == cohorts
        end
        
        it "should initialize cohorts to empty hash if not in the record" do
          connection.stub!(:find_user_data_by_ext_user_id).and_return([new_user_id, user_data_hash.merge("cohorts" => nil)])
          user_data.set_ext_user_id(ext_user_id)
          user_data.cohorts.should == {}
        end
      end
      
      context "if record not found" do
        before(:each) do
          connection.stub!(:find_user_data_by_ext_user_id).and_return(nil)
        end
      
        it "should update the current record with the external user id" do
          connection.should_receive(:set_user_data).with(user_id, "ext_user_id" => ext_user_id)
          user_data.set_ext_user_id(ext_user_id)
        end
      end
    end
  end
end