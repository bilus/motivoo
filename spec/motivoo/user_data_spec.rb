require 'spec_helper'
require 'motivoo/user_data'

module Motivoo
  describe UserData do
    let(:connection) { double("connection") }
    let(:env_no_user_id) { {"HTTP_COOKIE" => ""} }

    let(:user_id) { "user_id" }
    let(:env_with_user_id) { {"HTTP_COOKIE" => "#{UserData::USER_ID_COOKIE}=#{user_id}"} }
    let(:cohorts) { {"month" => "2012-10"} }

    let(:response) { double("response") }
    
    context "#deserialize_from!" do
      let(:user_data_hash) { {"cohorts" => cohorts} }

      it "should find or create user data if user id is in cookies" do
        connection.should_receive(:find_or_create_user_data).with(user_id).and_return(user_data_hash)
        user_data, _ = UserData.deserialize_from!(env_with_user_id, connection)
        user_data.cohorts.should == cohorts
      end
      
      it "should create user data set if no user id" do
        connection.should_receive(:generate_user_id).and_return(user_id)
        user_data, _ = UserData.deserialize_from!(env_no_user_id, connection)
        user_data.cohorts.should == {}
      end
      
      it "should make it possible to tell if it's a new or existing user id" do
        connection.stub(:generate_user_id)
        connection.stub(:find_or_create_user_data).and_return({})
        _, is_existing_user = UserData.deserialize_from!(env_no_user_id, connection)
        is_existing_user.should be_false
        _, is_existing_user = UserData.deserialize_from!(env_with_user_id, connection)
        is_existing_user.should be_true
      end
    end

    context "#serialize_into" do
      let(:new_user_id) { "new_user_id" }
      
      before(:each) do
        connection.stub(:find_or_create_user_data).and_return({})
      end

      it "should generate a new user id if user id wasn't in cookies" do
        connection.stub(:generate_user_id).and_return(new_user_id)
        user_data, _ = UserData.deserialize_from!(env_no_user_id, connection)
        response.should_receive(:set_cookie).with(anything, hash_including(value: new_user_id))
        user_data.serialize_into(response)
      end
      
      it "should set user id cookie if it was" do
        user_data, _ = UserData.deserialize_from!(env_with_user_id, connection)
        response.should_receive(:set_cookie).with(anything, hash_including(value: user_id))
        user_data.serialize_into(response)
      end
    end
    
    context "#assign_to" do
      let(:cohort_category) { "cohort_category" }
      let(:cohort) { "cohort" }
      let(:user_data) { UserData.new(user_id, {}, connection)}
      
      it "should update the database" do
        connection.should_receive(:assign_cohort).with(user_id, cohort_category, cohort)
        user_data.assign_to(cohort_category, cohort)
      end
      
      it "should make local changes" do
        connection.stub(:assign_cohort)
        user_data.assign_to(cohort_category, cohort)
        user_data.cohorts[cohort_category].should == cohort
      end
      
      it "should raise an error if user already assigned" do
        connection.stub(:assign_cohort)
        user_data.assign_to(cohort_category, cohort)
        lambda { user_data.assign_to(cohort_category, "#{cohort}2") }.should raise_error
        user_data.cohorts[cohort_category].should == cohort
      end
    end
    
    context "#set_ext_user_id(id) -- user logs in" do
      let(:ext_user_id) { "ext_user_id" }
      let(:other_ext_user_id) { "other_ext_user_id" }
      let(:new_user_id) { "new_user_id" }
      let(:existing_user_id) { "existing_user_id" }
      let(:user_data_hash) { {"cohorts" => cohorts} }

      context "when current user was not authenticated" do
        before(:each) do
          connection.stub(:set_user_data)
        end
        
        let!(:user_data) do
          connection.stub(:find_or_create_user_data).and_return({})
          UserData.deserialize_from!(env_with_user_id, connection).first
        end

        it "should search for the user's record" do
          connection.should_receive(:find_user_data_by_ext_user_id)
          user_data.set_ext_user_id(ext_user_id)
        end

        context "when the new user has a user data record" do
          before(:each) do
            connection.stub(:find_user_data_by_ext_user_id).and_return([existing_user_id, user_data_hash])
            connection.stub(:destroy_user_data)
          end
          
          it "should use the existing user data record contents" do
            user_data.set_ext_user_id(ext_user_id)
            user_data.cohorts.should == user_data_hash["cohorts"]
          end
          
          it "should use the id of the existing record" do
            user_data.set_ext_user_id(ext_user_id)
            response.should_receive(:set_cookie).with(anything, hash_including(value: existing_user_id))
            user_data.serialize_into(response)
          end
          
          it "should destroy the obsolete user data record" do
            connection.should_receive(:destroy_user_data).with(user_id)
            user_data.set_ext_user_id(ext_user_id)
          end
          
          it "should set the external user id" do
            user_data.set_ext_user_id(ext_user_id)
            user_data.ext_user_id.should == ext_user_id
          end
        end
        
        context "when the new user has no user data record" do
          before(:each) do
            connection.stub(:find_user_data_by_ext_user_id).and_return(nil)
          end

          it "should associate the current user data record with the new user" do
            connection.should_receive(:set_user_data).with(user_id, "ext_user_id" => ext_user_id)
            user_data.set_ext_user_id(ext_user_id)
          end

          it "should set the external user id" do
            user_data.set_ext_user_id(ext_user_id)
            user_data.ext_user_id.should == ext_user_id
          end
        end
      end
      
      context "when current user was authenticated" do
        let!(:user_data) do
          connection.stub(:find_or_create_user_data).and_return({"ext_user_id" => ext_user_id})
          UserData.deserialize_from!(env_with_user_id, connection).first
        end

        context "if it's the same external user" do
          it "should do nothing" do
            user_data.set_ext_user_id(ext_user_id)
          end
        end
        
        context "if it's a different external user" do
          
          it "should search for the user's record" do
            connection.should_receive(:find_user_data_by_ext_user_id).and_return([existing_user_id, user_data_hash])
            user_data.set_ext_user_id(other_ext_user_id)
          end
          
          context "when the new user has a user data record" do
            before(:each) do
              connection.stub(:find_user_data_by_ext_user_id).and_return([existing_user_id, user_data_hash])
            end
          
            it "should use the existing user data record contents" do
              user_data.set_ext_user_id(other_ext_user_id)
              user_data.cohorts.should == user_data_hash["cohorts"]
            end
          
            it "should use the id of the existing record" do
              user_data.set_ext_user_id(other_ext_user_id)
              response.should_receive(:set_cookie).with(anything, hash_including(value: existing_user_id))
              user_data.serialize_into(response)
            end
          end
          
          context "when the new user has no user data record" do
            before(:each) do
              connection.stub(:find_user_data_by_ext_user_id).and_return(nil)
              connection.stub(:set_user_data)
              connection.stub(:generate_user_id)
            end

            it "should create a new record" do
              connection.should_receive(:generate_user_id).and_return(new_user_id)
              user_data.set_ext_user_id(other_ext_user_id)
            end

            it "should associate the new record with the new user" do
              connection.stub(:generate_user_id).and_return(new_user_id)
              connection.should_receive(:set_user_data).with(new_user_id, "ext_user_id" => other_ext_user_id)
              user_data.set_ext_user_id(other_ext_user_id)
            end

            it "should set the external user id" do
              user_data.set_ext_user_id(other_ext_user_id)
              user_data.ext_user_id.should == other_ext_user_id
            end
          end
        end
      end
    end
    
    context "#set_ext_user_id(nil) -- user logs out" do
      let(:new_user_id) { "new_user_id" }
      let(:ext_user_id) { "ext_user_id" }
      
      context "when current user was authenticated" do
        let!(:user_data) do
          connection.stub(:find_or_create_user_data).and_return({"ext_user_id" => ext_user_id, "cohorts" => cohorts})
          UserData.deserialize_from!(env_with_user_id, connection).first
        end
        
        before(:each) do
          connection.stub(:generate_user_id).and_return(new_user_id)
        end
        
        it "should create and a new user data id" do
          connection.should_receive(:generate_user_id).and_return(new_user_id)
          user_data.set_ext_user_id(nil)
        end
        
        it "should clear cohorts" do
          user_data.set_ext_user_id(nil)
          user_data.cohorts.should == {}
        end
        
        it "should use the new record id" do
          user_data.set_ext_user_id(nil)
          response.should_receive(:set_cookie).with(anything, hash_including(value: new_user_id))
          user_data.serialize_into(response)
        end
        
        it "should set external user id to nil" do
          user_data.set_ext_user_id(nil)
          user_data.ext_user_id.should == nil
        end
      end
      
      context "when current user was not authenticated" do
        let!(:user_data) do
          connection.stub(:find_or_create_user_data).and_return({})
          UserData.deserialize_from!(env_with_user_id, connection).first
        end
        
        it "should do nothing" do
          user_data.set_ext_user_id(nil)
        end
      end
    end
    
    context "#[]= -- user defined fields" do
      let(:key) { "key" }
      let(:sample_value) { "sample_value" }
      let(:user_data) { UserData.new(user_id, {}, connection)}

      it "should allow reading" do
        connection.should_receive(:get_user_data).with(user_id, key).and_return(sample_value)
        user_data[key].should == sample_value
      end
      
      it "should allow updates" do
        connection.should_receive(:set_user_data).with(user_id, key => sample_value)
        user_data[key] = sample_value
      end
    end
  end
end