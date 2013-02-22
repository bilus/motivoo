require 'spec_helper'
require 'motivoo/tracker'

module Motivoo
  describe Tracker do
    let(:connection) { mock("connection").as_null_object }
    let(:request) { mock("request") }
    let(:user_data) do
      user_data = mock("user_data").as_null_object
      user_data
    end
    
    let(:tracker) { Tracker.new(user_data, connection) }
  
    before(:each) do
      user_data.stub!(:[]).and_return(nil)
    end
  
    context "when serializing into hash" do
      it "should return hash with an entry pointing to itself" do
        tracker.serialize_into({}).should == {"motivoo.tracker" => tracker}
      end
    end
    
    context "when deserializing from hash" do
      it "should return serialized tracker instance" do
        hash = tracker.serialize_into({})
        Tracker.deserialize_from(hash).should == tracker
      end
      
      it "should raise error if it's not there" do
        lambda { |opts = {}| tracker.deserialize_from({}) }.should raise_error
      end
    end
  
    shared_examples_for("tracking category") do
      let(:month_cohort) { "2012-12" }
      let(:week_cohort) { "2012(50)" }
      let(:day_cohort) { "2012-12-10" }
      
      it "should find out which cohorts the user is assigned to" do
        user_data.should_receive(:cohorts).and_return("month" => month_cohort, "week" => week_cohort, "day" => day_cohort)
        track.call
      end
      
      it "should track by month, week and day based on cohorts user is assigned to regardless of the time of visit" do
        user_data.stub!(:cohorts).and_return("month" => month_cohort, "week" => week_cohort, "day" => day_cohort)
        connection.should_receive(:track).with(expected_category, expected_status, "month", month_cohort)
        connection.should_receive(:track).with(expected_category, expected_status, "week", week_cohort)
        connection.should_receive(:track).with(expected_category, expected_status, "day", day_cohort)
        at("2013-01-01 12:00") { track.call }
      end
      
      it "should assign user to cohorts that are missing in user data based on current time" do
        user_data.stub!(:cohorts).and_return("day" => day_cohort)
        user_data.should_receive(:assign_to).with("week", "2013(1)")
        user_data.should_receive(:assign_to).with("month", "2013-01")
        at("2013-01-01 12:00") { track.call }
      end

      it "should use newly assigned cohorts when tracking" do
        user_data.stub!(:cohorts).and_return("day" => day_cohort)
        connection.should_receive(:track).with(expected_category, expected_status, "month", "2013-01")
        connection.should_receive(:track).with(expected_category, expected_status, "week", "2013(1)")
        connection.should_receive(:track).with(expected_category, expected_status, "day", day_cohort)
        at("2013-01-01 12:00") { track.call }
      end
      
      it "should track each category + status combination only once per user by default" do
        user_data.should_receive(:[]).and_return(nil)
        user_data.should_receive(:[]=)
        at("2013-01-01 12:00") { track.call }
        
        user_data.should_receive(:[]).and_return(true)
        connection.should_not_receive(:track)
        at("2013-01-01 12:00") { track.call }
      end
      
      it "should optionally track a category + status combination more than once per user" do
        user_data.stub!(:[]).and_return(true) # Even if already tracked.
        connection.should_receive(:track)
        at("2013-01-01 12:00") { track.call(allow_repeated: true) }
      end
    end
  
    shared_examples_for("an exception-safe method") do
      before(:each) do
        connection.stub!(:track).and_raise("An error")
        Kernel.stub!(:puts)
      end
      
      it "should not let exceptions out" do
        lambda { track.call }.should_not raise_error
      end
      
      it "should write the error to console" do
        Kernel.should_receive(:puts)
        track.call
      end
    end
  
    context "when tracking acquisition" do
      let(:track) { lambda { |opts = {}| tracker.acquisition(:visit, opts) } }
      it_should_behave_like("tracking category") do
        let(:expected_category) { "acquisition" }
        let(:expected_status) { "visit" }
      end
      it_should_behave_like("an exception-safe method")
    end
    
    context "when tracking activation" do
      let(:track) { lambda { |opts = {}| tracker.activation(:signup, opts) } }
      it_should_behave_like("tracking category") do
        let(:expected_category) { "activation" }
        let(:expected_status) { "signup" }
      end
      it_should_behave_like("an exception-safe method")
    end

    context "when tracking retention" do
      let(:track) { lambda { |opts = {}| tracker.retention(:frequent_poster, opts) } }
      it_should_behave_like("tracking category") do
        let(:expected_category) { "retention" }
        let(:expected_status) { "frequent_poster" }
      end
      it_should_behave_like("an exception-safe method")
    end

    context "when tracking referral" do
      let(:track) { lambda { |opts = {}| tracker.referral(:referred_active, opts) } }
      it_should_behave_like("tracking category") do
        let(:expected_category) { "referral" }
        let(:expected_status) { "referred_active" }
      end
      it_should_behave_like("an exception-safe method")
    end

    context "when tracking revenue" do
      let(:track) { lambda { |opts = {}| tracker.revenue(:order, opts) } }
      it_should_behave_like("tracking category") do
        let(:expected_category) { "revenue" }
        let(:expected_status) { "order" }
      end
      it_should_behave_like("an exception-safe method")
    end

    context "when external user id is set" do
      let(:ext_user_id) { "ext_user_id" }

      it "should delegate to user data" do
        user_data.should_receive(:set_ext_user_id).with(ext_user_id)
        tracker.set_ext_user_id(ext_user_id)
      end
    end
    
    context "defining cohorts" do
      it "should use it" do
        Tracker.define_cohort("build_number") do
          "123"
        end
        
        connection.should_receive(:track).with("acquisition", "visit", "build_number", "123")
        at("2013-01-01 12:00") { tracker.acquisition(:visit) }
      end
    end
  end
end