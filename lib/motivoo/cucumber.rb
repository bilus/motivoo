require 'motivoo'
require 'motivoo/cucumber/helper_steps'

Before do
  Motivoo::Connection.instance.clear!
  @test_cohort_categories = []
end

After do
  @test_cohort_categories.each do |category|
    Motivoo::Tracker.remove_cohort!(category)
  end
end