require 'spec_helper'
require 'sinatra'

describe "Integration with user accounts" do
  include SpecHelpers
  
  def app
    Rack::Builder.app do
      klass = Class.new(Sinatra::Base)
      
      klass.class_eval do
        use Rack::Motivoo
        
        get "/" do
        end
      
        get "/review" do
          Motivoo::Tracker.deserialize_from(env).activation(:review)
        end
              
        get "/login/:user" do
          tracker = Motivoo::Tracker.deserialize_from(env)
          tracker.set_ext_user_id(params[:user])
        end
        
        get "/signup/:user" do
          tracker = Motivoo::Tracker.deserialize_from(env)
          tracker.set_ext_user_id(params[:user])
          tracker.activation(:signup)
        end
      end
      
      run klass
    end
  end
  
  it "should not count login as a new first visit" do
    user1 = nil
    at("2012-10-10 12:00") { user1 = get("/") }
    at("2012-10-10 13:00") { get("/signup/user1", user1) }
    at("2012-12-15 14:00") { user1 = get("/login/user1") }
    report.acquisitions_by(:month, :first_visit).to_a.should_not include(["2012-12", 1])
  end

  it "should track user with user id in cookies" do
    user1 = nil
    
    at("2012-10-10 12:00") { user1 = get("/") }
    at("2012-10-10 13:00") { get("/signup/user1", user1) }
    at("2012-12-15 14:00") { get("/review", user1) }

    report.activations_by(:month, :review).should == {"2012-10" => 1}
  end

  it "should track user after login even without user id in cookies" do
    user1 = nil
    
    at("2012-10-10 12:00") { user1 = get("/") }
    at("2012-10-10 13:00") { get("/signup/user1", user1) }
    
    at("2012-12-15 14:00") { user1 = get("/login/user1") }
    at("2012-12-15 14:00") { get("/review", user1) }

    report.activations_by(:month, :review).should == {"2012-10" => 1}
    report.relative_activations_by(:month, :review, report.acquisitions_by(:month, :first_visit)).should == {"2012-10" => 1.0}
  end
  
  it "should count repeat signup only once" do
    user1 = nil
    at("2012-10-10 12:00") { user1 = get("/") }
    at("2012-10-10 13:00") { get("/signup/user1", user1) }
    at("2012-10-10 13:00") { get("/signup/user1", user1) }
    at("2012-10-10 13:00") { get("/signup/user1", user1) }
    at("2012-10-10 13:00") { get("/signup/user1", user1) }
    report.activations_by(:month, :signup).should == {"2012-10" => 1}
  end
  
  it "should support multiple users signing up one after another on the same machine" do
    user1, user2 = nil
    at("2012-10-10 12:00") { user1 = get("/") }
    at("2012-10-10 13:00") { user1 = get("/signup/user1", user1) }
    at("2012-10-10 13:00") { get("/signup/user2", user1) }
    report.activations_by(:month, :signup).should == {"2012-10" => 2}
  end

  it "should support multiple users signing up one after another on the same machine over and over again" do
    user1, user2 = nil
    at("2012-10-10 12:00") { user1 = get("/") }
    at("2012-10-10 13:00") { user1 = get("/signup/user1", user1) }
    at("2012-10-10 13:00") { user2 = get("/signup/user2", user1) }
    at("2012-10-10 13:00") { user1 = get("/signup/user1", user2) }
    at("2012-10-10 13:00") { user2 = get("/signup/user2", user1) }
    report.activations_by(:month, :signup).should == {"2012-10" => 2}
  end

  it "should support multiple users signing up one after another assigning to the right cohorts" do
    user1, user2 = nil
    at("2012-10-10 12:00") { user1 = get("/") }
    at("2012-10-10 13:00") { user1 = get("/signup/user1", user1) }
    at("2012-12-10 13:00") { user2 = get("/signup/user2", user1) }
    report.activations_by(:month, :signup).should == {"2012-10" => 1, "2012-12" => 1}
  end
end