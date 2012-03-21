require 'spec_helper'

describe Hijacker::Alias do
  it "belongs to a database" do
    lambda { subject.database }.should_not raise_error
  end
end
