require "spec_helper"

describe Hijacker do
  describe "#find_shared_sites_for" do
    let!(:master) { Hijacker::Database.create(:database => "master_db") }
    let!(:sister) {Hijacker::Database.create(:database => "sister_db", :master_id => master.id)}
    let!(:sister2) {Hijacker::Database.create(:database => "sister_db2", :master_id => master.id)}
    let!(:unrelated) {Hijacker::Database.create(:database => "unrelated_db")}
    let!(:unrelated_sister) {Hijacker::Database.create(:database => "unrelated_sister", :master_id => unrelated.id)}

    it "find shared sites given a master or sister database" do
      dbs = ["master_db","sister_db","sister_db2"]
      Hijacker::Database.find_shared_sites_for("master_db").should == dbs
      Hijacker::Database.find_shared_sites_for("sister_db").should == dbs
    end
  end

end
