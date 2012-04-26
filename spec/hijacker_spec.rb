require "spec_helper"

describe Hijacker do
  let(:hosted_environments) { %w[staging production] }

  before(:each) do
    Hijacker.config = {
      :hosted_environments => hosted_environments
    } 
  end

  let!(:host) { Hijacker::Host.create!(:hostname => "localhost") }
  let!(:master) { Hijacker::Database.create!(:database => "master_db", :host => host) }

  describe ".find_shared_sites_for" do
    let!(:sister) {Hijacker::Database.create(:database => "sister_db",
                                             :master => master,
                                             :host => host)}
    let!(:sister2) {Hijacker::Database.create(:database => "sister_db2",
                                              :master => master,
                                              :host => host)}
    let!(:unrelated) {Hijacker::Database.create(:database => "unrelated_db",
                                                :host => host)}
    let!(:unrelated_sister) {Hijacker::Database.create(:database => "unrelated_sister",
                                                       :master => unrelated,
                                                       :host => host)}

    it "find shared sites given a master or sister database" do
      dbs = ["master_db","sister_db","sister_db2"]
      Hijacker::Database.find_shared_sites_for("master_db").should == dbs
      Hijacker::Database.find_shared_sites_for("sister_db").should == dbs
    end
  end

  describe "class methods" do 
    subject { Hijacker }

    describe ".connect" do
      let(:perform_caching) { false }

      before(:each) do
        subject.master = nil
        subject.sister = nil
        subject.valid_routes = {}
        ActiveRecord::Base.stub(:establish_connection)
        subject.stub(:root_connection).and_return(stub(:config => {}))
        subject.stub(:connect_sister_site_models)
        Hijacker.stub(:do_hijacking?).and_return(true)
        ::ActionController::Base.stub(:perform_caching).
                                 and_return(perform_caching)
      end

      it "raises an InvalidDatabase exception if master is nil" do
        expect { subject.connect(nil) }.to raise_error(Hijacker::InvalidDatabase)
      end

      it "establishes a connection merging in the db name and the hostname"  do
        Hijacker::Database.create!(:database => 'elsewhere', :host => host)
        ActiveRecord::Base.should_receive(:establish_connection).
          with(hash_including("database" => 'elsewhere', "host" => "localhost"))
        subject.connect('elsewhere')
      end

      it "checks the connection by calling ActiveRecord::Base.connection" do
        subject.should_receive(:check_connection)
        subject.connect("master_db")
      end

      it "attempts to find an alias" do
        Hijacker::Alias.should_receive(:find_by_name).with('alias_db')
        subject.connect('alias_db') rescue nil
      end

      it "caches the valid route at the class level :(" do
        subject.connect('master_db')
        subject.valid_routes['master_db'].should == master
      end

      context "there's an alias for the master" do
        let!(:alias_db) { Hijacker::Alias.create(:name => 'alias_db', :database => master)}

        it "connects with the alias to the master and the host" do
          ActiveRecord::Base.should_receive(:establish_connection).
            with(hash_including('database' => 'master_db',
                                'host' => "localhost"))
          subject.connect('alias_db')
        end

        it "caches the valid route at the class level :(" do
          subject.connect('alias_db')
          subject.valid_routes['alias_db'].should == master
        end
      end

      context "ActiveRecord reports the connection is invalid" do
        before(:each) do
          subject.stub(:check_connection).and_raise("oh no you didn't")
        end

        it "reestablishes the root connection" do
          ActiveRecord::Base.should_receive(:establish_connection).with('root')
          subject.connect('master_db') rescue nil
        end

        it "re-raises the error" do
          expect { subject.connect("master_db") }.to raise_error("oh no you didn't")
        end
      end

      context "already connected to database" do
        before(:each) do
          Hijacker.master = 'master_db'
          Hijacker.sister = nil
        end

        after(:each) do
          Hijacker.master = nil
        end

        it "does not reconnect" do
          ActiveRecord::Base.should_not_receive(:establish_connection)
          subject.connect('master_db')
        end
      end

      context "sister site specified" do
        let!(:sister_db) { Hijacker::Database.create!(:database => 'sister_db',
                                                      :master => master,
                                                      :host => host)}
        it "does reconnect if specifying a different sister" do
          ActiveRecord::Base.should_receive(:establish_connection)
          subject.connect('master_db', 'sister_db')
        end

        it "does not cache the route" do
          subject.connect('master_db', 'sister_db')
          subject.valid_routes.should_not have_key('sister_db')
        end

        it "raises InvalidDatabase if the sister does not exist" do
          expect do
            subject.connect("master_db", "adopted_sister_db")
          end.to raise_error(Hijacker::InvalidDatabase)
        end
      end

      context "actioncontroller configured for caching" do
        let(:perform_caching) { true }

        it "enables the query cache on ActiveRecord::Base" do
          subject.connect('master_db')
          ::ActiveRecord::Base.connection.query_cache_enabled.should be_true
        end

        it "calls cache on the connection" do
          ::ActiveRecord::Base.connection.should_receive(:cache)
          subject.connect('master_db')
        end
      end

      context "after_hijack call specified" do
        let(:spy) { stub.as_null_object }
        before(:each) do
          Hijacker.config.merge!(:after_hijack => spy)
        end

        it "calls the callback" do
          spy.should_receive(:call)
          subject.connect('master_db')
        end
      end
    end

    describe ".check_connection" do
      it "calls connection on ActiveRecord::Base" do
        ::ActiveRecord::Base.should_receive(:connection)
        subject.check_connection
      end
    end
  end
end
