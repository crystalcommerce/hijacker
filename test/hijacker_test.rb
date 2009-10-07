require 'test_helper'

class HijackerTest < ActiveSupport::TestCase
  test "find shared sites given a master or sister database" do
    master = Hijacker::Database.create(:database => "master_db")
    sister = Hijacker::Database.create(:database => "sister_db", :master_id => master.id)
    sister2 = Hijacker::Database.create(:database => "sister_db2", :master_id => master.id)
    unrelated = Hijacker::Database.create(:database => "unrelated_db")
    unrelated_sister = Hijacker::Database.create(:database => "unrelated_sister", :master_id => unrelated.id)
    assert_equal ["master_db","sister_db","sister_db2"], Hijacker::Database.find_shared_sites_for("master_db")
    assert_equal ["master_db","sister_db","sister_db2"], Hijacker::Database.find_shared_sites_for("sister_db")
  end
end
