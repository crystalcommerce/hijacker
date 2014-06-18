require 'spec_helper'

describe Hijacker::Host do
  it "validates the format of the hostname" do
    subject.hostname = "lol nope"
    subject.should_not be_valid
    subject.errors[:hostname].should == ["is invalid"]

    subject.hostname = nil
    subject.should_not be_valid
    subject.errors[:hostname].should == ["is invalid"]

    subject.hostname = "db-01.example.com"
    subject.should be_valid

    subject.hostname = "192.168.1.1"
    subject.should be_valid

    subject.hostname = "2001:cdba::3257:9652"
    subject.should be_valid
  end
end
