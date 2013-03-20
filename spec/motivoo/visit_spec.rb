require 'spec_helper'
require 'motivoo/visit'

module Motivoo
  
  describe Visit do
    let(:tracker) { mock("tracker").as_null_object }
    let(:request) { mock("request").as_null_object }
    let(:response) { mock("response").as_null_object }

    it "should yield" do
      yielded = false
      Visit.track(tracker, request) do
        yielded = true
        response
      end
      yielded.should be_true
    end
    
    it "should yield with tracker and request" do
      Visit.track(tracker, request) do |arg1, arg2|
        arg1.should == tracker
        arg2.should == request
        response
      end
    end

    context "when tracking a visit" do
      let(:user_id) { "user_id" }
      let(:different_user_id) { "different_user_id" }
      
      context "when visit not tracked yet" do
        before(:each) do
          request.stub(:cookies).and_return(double(:[] => nil))
          tracker.stub(:user_id).and_return(user_id)
        end

        it "should track it" do
          tracker.should_receive(:acquisition).with(:visit, anything)
          Visit.track(tracker, request) { response }
        end
    
        it "should store user id in a session cookie to mark session as tracked" do
          response.should_receive(:set_cookie).with(anything, hash_including(value: user_id))
          Visit.track(tracker, request) { response }
        end
        
        it "should allow repeat visits" do
          tracker.should_receive(:acquisition).with(:visit, hash_including(allow_repeated: true))
          Visit.track(tracker, request) { response }
        end
        
        it "should not track if block raises an error and pass the error" do
          tracker.should_not_receive(:acquisition)
          expect { Visit.track(tracker, request) { raise "Error." } }.to raise_error
        end
      end

      context "when visit already tracked" do
        context "for the same user" do
          before(:each) do
            request.stub(:cookies).and_return(double(:[] => user_id))
            tracker.stub(:user_id).and_return(user_id)
          end

          it "should not track it" do
            tracker.should_not_receive(:acquisition).with(:visit, anything)
            Visit.track(tracker, request) { response }
          end
        end
        
        context "for a different user" do
          before(:each) do
            request.stub(:cookies).and_return(double(:[] => user_id))
            tracker.stub(:user_id).and_return(different_user_id)
          end

          it "should track it" do
            tracker.should_receive(:acquisition).with(:visit, anything)
            Visit.track(tracker, request) { response }
          end
    
          it "should store user id in a session cookie to mark session as tracked" do
            response.should_receive(:set_cookie).with(anything, hash_including(value: different_user_id))
            Visit.track(tracker, request) { response }
          end
        end
      end
    end
    
    context "when tracking the first visit" do
      it "should delegate to tracker" do
        tracker.should_receive(:acquisition).with(:first_visit)
        Visit.track(tracker, request) { response }
      end
    end
 
    it "should return response" do
      Visit.track(tracker, request) { response }.should == response
    end
  end
end