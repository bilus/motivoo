require 'spec_helper'
require 'motivoo/connection'

describe Motivoo::Connection do
  let(:connection) { Motivoo::Connection.new }
  let(:period_name) { "month" }
  let(:period1) { "2013-10" }
  let(:period2) { "2013-12" }
  
  context "[tracking]" do
    it "should not track anything initially" do
      connection.find("acquisition", "visit", period_name).should == {}
    end
  
    it "should create initial record with usage count of 1" do
      connection.track("acquisition", "visit", period_name, period1)
      connection.track("acquisition", "visit", period_name, period2)
      connection.find("acquisition", "visit", period_name).should == {period1 => 1, period2 => 1}
    end
  
    it "should inc usage count" do
      connection.track("acquisition", "visit", period_name, period1)
      connection.track("acquisition", "visit", period_name, period2)
      connection.track("acquisition", "visit", period_name, period2)
      connection.track("acquisition", "visit", period_name, period2)
      connection.find("acquisition", "visit", period_name).should == {period1 => 1, period2 => 3}
    end
  end  
  
  context "[user data]" do
    let(:id) { BSON::ObjectId.new }

    it "should create user data if it isn't there setting its id" do
      connection.find_or_create_user_data(id).should == {"_id" => id} # TODO: It should not return _id at all. Once records can be modified and be told apart, rewrite the spec.
    end

    it "should find user data if it's already there" do
      existing = connection.find_or_create_user_data(id)
      connection.find_or_create_user_data(id).should == {"_id" => id}
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
  end
end