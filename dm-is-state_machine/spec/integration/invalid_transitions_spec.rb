require 'spec_helper'

describe "InvalidTransitions1" do

  it "should get InvalidContext when requiring" do
    lambda {
      require 'examples/invalid_transitions_1'
    }.should raise_error(DataMapper::Is::StateMachine::InvalidContext)
  end

end

describe "InvalidTransitions2" do

  it "should get InvalidContext when requiring" do
    lambda {
      require 'examples/invalid_transitions_2'
    }.should raise_error(DataMapper::Is::StateMachine::InvalidContext)
  end

end
