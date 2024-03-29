require 'spec_helper'
require 'motivoo/tracker'

module Motivoo
  describe Tracker do
    let(:connection) { double("connection").as_null_object }
    let(:request) { double("request") }
    let(:user_data) do
      user_data = double("user_data").as_null_object
      user_data
    end
    
    let(:tracker) { Tracker.new(user_data, connection) }
  
    before(:each) do
      user_data.stub(:[]).and_return(nil)
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
      let(:month_cohort) { "2013-01" }
      let(:week_cohort) { "2013(1)" }
      let(:day_cohort) { "2013-01-01" }
      
      after(:each) do
        Tracker.remove_cohort!("source")
      end
      
      it "should find out which cohorts the user is assigned to" do
        user_data.should_receive(:cohorts).and_return("month" => month_cohort, "week" => week_cohort, "day" => day_cohort)
        track.call
      end
      
      it "should track by month, week and day based on cohorts user is assigned to regardless of the time of visit" do
        user_data.stub(:cohorts).and_return("month" => month_cohort, "week" => week_cohort, "day" => day_cohort)
        connection.should_receive(:track).with(expected_category, expected_event, "month", month_cohort)
        connection.should_receive(:track).with(expected_category, expected_event, "week", week_cohort)
        connection.should_receive(:track).with(expected_category, expected_event, "day", day_cohort)
        at("2013-01-01 12:00") { track.call }
      end
      
      it "should make it possible to create cohorts based on env" do
        source = double("source")
        env = tracker.serialize_into({source: source})
        t = Tracker.deserialize_from(env)
        Tracker.define_cohort("source") do |env|
          env[:source]
        end
        
        user_data.should_receive(:assign_to).with("source", source)
        track.call
      end
      
      context "given user is not assigned to any cohorts yet" do
        before(:each) do
          user_data.stub(:cohorts).and_return(
            {}, 
            {"month" => month_cohort, "week" => week_cohort, "day" => day_cohort})
        end
        
        it "should assign user to cohorts" do
          user_data.should_receive(:assign_to).with("day", day_cohort)
          user_data.should_receive(:assign_to).with("week", week_cohort)
          user_data.should_receive(:assign_to).with("month", month_cohort)
          at("2013-01-01 12:00") { track.call }
        end

        it "should track each cohort" do
          connection.should_receive(:track).with(expected_category, expected_event, "month", month_cohort)
          connection.should_receive(:track).with(expected_category, expected_event, "week", week_cohort)
          connection.should_receive(:track).with(expected_category, expected_event, "day", day_cohort)
          at("2013-01-01 12:00") { track.call }
        end
        
        it "should track each category + event combination only once per user by default" do
          user_data.should_receive(:[]).and_return(nil)
          user_data.should_receive(:[]=)
          at("2013-01-01 12:00") { track.call }
        
          user_data.should_receive(:[]).and_return(true)
          connection.should_not_receive(:track)
          at("2013-01-01 12:00") { track.call }
        end
      
        it "should optionally track a category + event combination more than once per user" do
          user_data.stub(:[]).and_return(true) # Even if already tracked.
          connection.should_receive(:track)
          at("2013-01-01 12:00") { track.call(allow_repeated: true) }
        end
      
        it "should not track nil cohorts" do
          Tracker.stub(:cohorts).and_return("seen_promotion" => proc { nil })
          user_data.should_not_receive(:assign_to).with("seen_promotion", nil)
          user_data.should_not_receive(:track).with(anything, anything, "seen_promotion", nil)
          at("2013-01-01 12:00") { track.call }
        end
        
        context "after a new cohort is defined" do
          after(:each) do
            Tracker.remove_cohort!("build_number")
          end
          
          it "should use it" do
            Tracker.define_cohort("build_number") do
              "123"
            end
        
            user_data.should_receive(:assign_to).with("build_number", "123")
            at("2013-01-01 12:00") { tracker.acquisition(:visit) }
          end
        end
      end

      context "given user is already assigned to a cohort" do
        before(:each) do
          user_data.stub(:cohorts).and_return("day" => day_cohort)
        end

        it "should not assign user to cohorts" do
          user_data.should_not_receive(:assign_to)
          at("2013-01-01 12:00") { track.call }
        end

        it "should track using the existing cohorts only" do
          connection.should_receive(:track).with(expected_category, expected_event, "day", day_cohort)
          connection.should_not_receive(:track).with(expected_category, expected_event, "month", anything)
          connection.should_not_receive(:track).with(expected_category, expected_event, "week", anything)
          at("2013-01-01 12:00") { track.call }
        end
      end
    end
  
    shared_examples_for("an exception-safe method") do
      before(:each) do
        user_data.stub(:cohorts).and_raise("An error")
        Kernel.stub(:puts)
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
        let(:expected_event) { "visit" }
      end
      it_should_behave_like("an exception-safe method")
    end
    
    context "when tracking activation" do
      let(:track) { lambda { |opts = {}| tracker.activation(:signup, opts) } }
      it_should_behave_like("tracking category") do
        let(:expected_category) { "activation" }
        let(:expected_event) { "signup" }
      end
      it_should_behave_like("an exception-safe method")
    end

    context "when tracking retention" do
      let(:track) { lambda { |opts = {}| tracker.retention(:frequent_poster, opts) } }
      it_should_behave_like("tracking category") do
        let(:expected_category) { "retention" }
        let(:expected_event) { "frequent_poster" }
      end
      it_should_behave_like("an exception-safe method")
    end

    context "when tracking referral" do
      let(:track) { lambda { |opts = {}| tracker.referral(:referred_active, opts) } }
      it_should_behave_like("tracking category") do
        let(:expected_category) { "referral" }
        let(:expected_event) { "referred_active" }
      end
      it_should_behave_like("an exception-safe method")
    end

    context "when tracking revenue" do
      let(:track) { lambda { |opts = {}| tracker.revenue(:order, opts) } }
      it_should_behave_like("tracking category") do
        let(:expected_category) { "revenue" }
        let(:expected_event) { "order" }
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
    
    context "#before_event callbacks" do
      let(:callback) { mock_event_handler }
      let(:skip) { lambda { |*args| skip! } }
      let(:noop)  { lambda { |*args| } }
      
      before(:each) do
        Tracker.before_acquisition(&callback)
      end
      
      after(:each) do
        Tracker.before_any {}
        Tracker.before_acquisition {}
        Tracker.before_activation {}
      end
      
      it "should invoke once with event" do
        callback.should_receive(:call).once.with(:visit, anything, anything, anything)
        tracker.acquisition(:visit)
      end
      
      it "should allow user to skip" do
        Tracker.before_acquisition do |event|
          skip!
        end
        connection.should_not_receive(:track)
        tracker.acquisition(:visit)
      end
      
      it "should pass the env, tracker and user data into the handler" do
        env = {foo: "bar"}
        tracker.serialize_into(env)
        callback.should_receive(:call).once.with(anything, env, tracker, user_data)
        tracker.acquisition(:visit)
      end
      
      it "should skip if before_any skips" do
        Tracker.before_any(&skip)
        Tracker.before_activation(&noop)
        connection.should_not_receive(:track)
        tracker.activation(:signup)
      end
      
      it "should skip if before_activation skips" do
        Tracker.before_any(&noop)
        Tracker.before_activation(&skip)
        connection.should_not_receive(:track)
        tracker.activation(:signup)
      end
      
      it "should not invoke before_activation if before_any skips" do
        Tracker.before_any(&skip)
        before_activation_called = false
        Tracker.before_activation do
          before_activation_called = true
        end
        tracker.activation(:signup)
        before_activation_called.should be_false
      end
    end
    
    context "#before_tracking callback" do
      let(:callback) { mock_event_handler }
      let(:skip) { lambda { |*args| skip! } }
      let(:noop)  { lambda { |*args| } }
      
      before(:each) do
        Tracker.before_tracking(&callback)
      end
      
      after(:each) do
        Tracker.before_tracking {}
      end
      
      it "should invoke once with event" do
        callback.should_receive(:call).once.with(:visit, anything, anything, anything)
        tracker.acquisition(:visit)
      end
      
      it "should allow user to skip" do
        Tracker.before_tracking do |*args|
          skip!
        end
        connection.should_not_receive(:track)
        tracker.acquisition(:visit)
      end
      
      it "should pass the env, tracker and user data into the handler" do
        env = {foo: "bar"}
        tracker.serialize_into(env)
        callback.should_receive(:call).once.with(anything, env, tracker, user_data)
        tracker.acquisition(:visit)
      end
    end
    
    context "[repeat visit callback]" do
      let(:callback) { mock_event_handler }
  
      before(:each) do 
        Tracker.on_repeat_visit(&callback)
      end
  
      after(:each) do
        Tracker.on_repeat_visit {}
      end

      context "when it is created" do
        it "should invoke the callback for existing user" do
          callback.should_receive(:call).with(kind_of(Tracker), user_data)
          Tracker.new(user_data, connection, existing_user: true)
        end

        it "should not invoke the callback for new user" do
          callback.should_not_receive(:call)
          Tracker.new(user_data, connection, existing_user: false)
        end
      end

      context "when external user id is set" do
        let(:ext_user_id) { "ext_user_id" }
      
        it "should invoke the callback whenever it changes user id" do
          id1 = "id1"
          id2 = "id2"
          user_data.stub(:user_id).and_return(id1, id2)
          callback.should_receive(:call).with(tracker, user_data)
          tracker.set_ext_user_id(ext_user_id)
        end

        it "should not invoke the callback for unchanged user id" do
          id = "id"
          user_data.stub(:user_id).and_return(id, id)
          callback.should_not_receive(:call)
          tracker.set_ext_user_id(ext_user_id)
        end
      end
    end    
    
    context "when asked to act as a user" do
      let(:ext_user_id) { "ext_user_id" }
      let(:new_user_data) { double("new_user_data", set_ext_user_id: nil, :[] => nil, :[]= => nil, cohorts: {}, assign_to: nil) }
      let(:callback) { mock_event_handler }
      
      before(:each) do
        user_data.stub(:clone).and_return(new_user_data)
        Tracker.before_acquisition(&callback)
      end
    
      after(:each) do
        Tracker.before_acquisition {}
      end
      
      it "should return a different tracker instance" do
        new_user_data.stub(:set_ext_user_id)
        tracker.act_as(ext_user_id).should_not == tracker
      end

      it "should use new user data" do
        user_data.should_not_receive(:set_ext_user_id).with(ext_user_id)
        user_data.should_receive(:clone).and_return(new_user_data)
        new_user_data.should_receive(:set_ext_user_id).with(ext_user_id)
        tracker.act_as(ext_user_id)
      end

      it "should create a copy of env" do
        original_env = tracker.serialize_into({})
        Tracker.deserialize_from(original_env).should == tracker
        callback.should_receive(:call) do |_event, env, *_args|
          env.should be_a(Hash)
          env.should_not == original_env
        end
        tracker.act_as(ext_user_id).acquisition(:visit)
      end
    end
    
    context "when asked to simulate tracking on a different date" do
      let(:month_cohort) { "2012-12" }
      let(:week_cohort) { "2012(50)" }
      let(:day_cohort) { "2012-12-10" }

      it "should assign to the correct cohort" do
        user_data.stub(:cohorts).and_return({})
        user_data.should_receive(:assign_to).with("day", day_cohort)
        user_data.should_receive(:assign_to).with("week", week_cohort)
        user_data.should_receive(:assign_to).with("month", month_cohort)
        tracker.acquisition(:visit, on_date: Time.parse("2012-12-10").to_date)
      end
    end
  end
end