require 'spec_helper'

describe "Optionally disable tracking for some users" do
  include SpecHelpers
  
  def app
    Rack::Builder.app do
      use Rack::Motivoo
      map "/" do
        run lambda { |env|
          [200, {'Content-Type' => 'text/plain'}, ["Hello"]]
        }
      end
      
      map "/login" do
        run lambda { |env|
          tracker = Motivoo::Tracker.deserialize_from(env)
          tracker.set_ext_user_id("123")
          [200, {'Content-Type' => 'text/plain'}, ["Hello"]]
        }
      end

      map "/signup" do
        run lambda { |env|
          tracker = Motivoo::Tracker.deserialize_from(env)
          tracker.set_ext_user_id("123")
          tracker.activation(:signup)
          [200, {'Content-Type' => 'text/plain'}, ["Hello"]]
        }
      end
    end
  end

  shared_examples_for "app with option to disable tracking" do
    before(:each) do
      Motivoo.configure do |config|
        config.disable_tracking do |env|
          query_string = env["QUERY_STRING"]
          query_string.include?("ignore=true")
        end
      end
    end
    
    context "with the extra query param" do
      let(:user) { at("2012-12-12 15:00") { post("/motivoo/?ignore=true") } } # For bot-protected app.
      
      it "should not count visits" do
        u = user
        at("2012-12-12 15:00") { u = get("/?ignore=true", u) }
        at("2012-12-12 15:00") { get("/?ignore=true", u) }
        report.acquisitions_by(:month, :first_visit).should == {}
      end
    end
  
    context "without the extra query param" do
      let(:user) { at("2012-12-12 15:00") { post("/motivoo/") } } # For bot-protected app.

      it "should count first visits" do
        u = user
        at("2012-12-12 15:00") { u = get("/", u) }
        at("2012-12-12 15:00") { get("/", u) }
        report.acquisitions_by(:month, :first_visit).should == {"2012-12" => 1}
      end
    end
  end    
  
  context "with bot protection" do
    before(:each) do
      Motivoo.configure do |config|
        config.bot_protect_js = true
      end
    end
  
    it_should_behave_like "app with option to disable tracking"
  end

  context "without bot protection" do
    before(:each) do
      Motivoo.configure do |config|
        config.bot_protect_js = false
      end
    end
  
    it_should_behave_like "app with option to disable tracking"
  end
end