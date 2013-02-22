require 'spec_helper'
require 'motivoo/connection'

describe Motivoo::Connection do
  let(:connection) { Motivoo::Connection.new }
  let(:cohort_name) { "month" }
  let(:cohort1) { "2013-10" }
  let(:cohort2) { "2013-12" }
  
  context "[tracking]" do
    it "should not track anything initially" do
      connection.find("acquisition", "visit", cohort_name).should == {}
    end
  
    it "should create initial record with usage count of 1" do
      connection.track("acquisition", "visit", cohort_name, cohort1)
      connection.track("acquisition", "visit", cohort_name, cohort2)
      connection.find("acquisition", "visit", cohort_name).should == {cohort1 => 1, cohort2 => 1}
    end
  
    it "should inc usage count" do
      connection.track("acquisition", "visit", cohort_name, cohort1)
      connection.track("acquisition", "visit", cohort_name, cohort2)
      connection.track("acquisition", "visit", cohort_name, cohort2)
      connection.track("acquisition", "visit", cohort_name, cohort2)
      connection.find("acquisition", "visit", cohort_name).should == {cohort1 => 1, cohort2 => 3}
    end
  end    
  
  context "[user data]" do
    let(:id) { BSON::ObjectId.new.to_s }

    it "should create user data if it isn't there setting its id" do
      connection.find_or_create_user_data(id).should == {}
    end

    it "should find user data if it's already there" do
      existing = connection.find_or_create_user_data(id)
      connection.assign_cohort(id, cohort_name, cohort1)
      connection.find_or_create_user_data(id).should == {"cohorts" => {cohort_name => cohort1}}
    end
    
    it "should generate user id" do
      connection.generate_user_id.should_not == connection.generate_user_id
    end
    
    it "should assign to cohort" do
      user_id = connection.generate_user_id
      cohort_name = "cohort_name"
      cohort = "cohort"
      connection.assign_cohort(user_id, cohort_name, cohort)
      connection.find_or_create_user_data(user_id)["cohorts"].should == {cohort_name => cohort}
    end
    
    context "when finding by external user id" do
      let(:ext_user_id) { "ext_user_id" }
      
      it "should return nil if it isn't there" do
        connection.find_user_data_by_ext_user_id(ext_user_id).should == nil
      end

      it "should find user data if it's already there" do
        connection.find_or_create_user_data(id)
        connection.assign_cohort(id, "release", "v1")
        connection.set_user_data(id, "ext_user_id" => ext_user_id)
        connection.find_user_data_by_ext_user_id(ext_user_id).should == [id, {"ext_user_id" => ext_user_id, "cohorts" => {"release" => "v1"}}]
      end
    end   
    
    context "when destroying orphaned user data" do
      it "should no longer find it" do
        existing = connection.find_or_create_user_data(id)
        connection.assign_cohort(id, cohort_name, cohort1)
        connection.destroy_user_data(id)
        connection.find_or_create_user_data(id).should == {}
      end
    end 
    
    context "user-defined fields" do
      let(:key) { "key" }
      let(:sample_value) { "sample_value" }
      let!(:user_id) { connection.generate_user_id }
      
      it "should return nil if field not set" do
        connection.get_user_data(user_id, key).should be_nil
      end
      
      it "should allow updates" do
        connection.set_user_data(user_id, key => sample_value)
        connection.get_user_data(user_id, key).should == sample_value
      end
    end
  end
end