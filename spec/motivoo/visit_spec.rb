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
    
    context "visit not tracked yet" do
      before(:each) do
        request.stub(:cookies).and_return(double(:[] => nil))
      end

      it "should track visit" do
        tracker.should_receive(:acquisition)
        Visit.track(tracker, request) { response }
      end
    
      it "should store session cookie to mark session as tracked" do
        response.should_receive(:set_cookie)
        Visit.track(tracker, request) { response }
      end
    end
    

    context "visit already tracked" do
      it "should not track it" do
        tracker.should_not_receive(:acquisition)
        request.stub(:cookies).and_return(double(:[] => true))
        Visit.track(tracker, request) { response }
      end
    end
    
    it "should return response" do
      Visit.track(tracker, request) { response }.should == response
    end
  end
end