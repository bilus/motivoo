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
          # puts "/"
        end
      
        get "/review" do
          # puts "/review"
          Motivoo::Tracker.deserialize_from(env).activation(:review)
        end
              
        get "/login/:user" do
          # puts "/login/#{params[:user]}"
          tracker = Motivoo::Tracker.deserialize_from(env)
          tracker.set_ext_user_id(params[:user])
        end
        
        get "/signup/:user" do
          # puts "/signup/#{params[:user]}"
          tracker = Motivoo::Tracker.deserialize_from(env)
          tracker.set_ext_user_id(params[:user])
          tracker.activation(:signup)
        end
        
        get "/logout" do
          # puts "/logout"
          tracker = Motivoo::Tracker.deserialize_from(env)
          tracker.set_ext_user_id(nil)
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
  
  it "should support logout" do
    user1, user2, user3 = nil
    at("2012-10-10 12:00") { user1 = get("/") }
    at("2012-10-10 13:00") { user1 = get("/login/user1", user1) }
    at("2012-11-10 13:00") { user1 = get("/logout", user1) }
    
    at("2012-12-10 13:00") { user2 = get("/login/user2") }
    at("2012-12-10 14:00") { user3 = get("/logout", user2) }
    at("2012-12-10 15:00") { get("/", user3) }
    report.acquisitions_by(:month, :first_visit).should == {"2012-10" => 1, "2012-11" => 1, "2012-12" => 2}
    
    # NOTE: It would be great if it didn't count the Nov logout as a new first visit but it is a side-effect of visits
    # being tracked _after_ request is processed, i.e. after the call to tracker.set_ext_user_id(nil).
    # Anyway, if this breaks, analyze but this isn't necessarily a symptom of a problem.
  end

  it "should count visit in the same session once per user" do
    user1, user2 = nil, nil
    at("2012-12-12 15:00") { user1 = get("/") }
    at("2012-12-12 15:00") { user1 = get("/login/user1", user1) }
    at("2012-12-12 15:00") { user2 = get("/login/user2", user1) }
    report.acquisitions_by(:month, :visit).should == {"2012-12" => 2}
  end
end