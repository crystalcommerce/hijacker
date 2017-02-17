require "spec_helper"

module Hijacker
  describe Database do
    # before(:each) do
    #   $hijacker_redis.del('test:hijacker:unresponsive-dbhost-ids')
    # end
    
    let(:host) { Hijacker::Host.create!(:hostname => "localhost") }
    let(:alias_db) { Hijacker::Alias.new(:name => "alias_db") }

    it "has many aliases" do
      subject.aliases << alias_db
      subject.aliases.should == [alias_db]
    end

    it "belongs to a host" do
      subject.host = host
      subject.host.should == host
    end

    it "requires a host" do
      subject.host = nil
      subject.should_not be_valid
      subject.errors[:host_id].should == ["can't be blank"]

      subject.host = host
      subject.should be_valid
    end

    it "aliases name to database" do
      subject.database = "foo"
      subject.name.should == "foo"
      subject.name = "bar"
      subject.database.should == "bar"
    end

    it "aliases find_by_name to find_by_database" do
      Hijacker::Database.should_receive(:find_by_database).with("foo")
      Hijacker::Database.find_by_name("foo")
    end

    describe "#connect_each" do
      def db(name)
        double("#{name}_db", :database => name)
      end

      before (:each) do
        Database.stub(:with_responsive_hosts).and_return([ db("one"), db("two"), db("three") ])
        Hijacker.stub(:connect)
      end

      it "Calls the block once for each database" do
        count = 0
        Database.connect_each do |db|
          count += 1
        end
        count.should == Database.with_responsive_hosts.size
      end

      it "Passes the name of the database to the block" do
        db_names = []
        Database.connect_each do |db|
          db_names << db
        end
        db_names.should == Database.with_responsive_hosts.map(&:database)
      end

      it "connects to each of the database and reconnects to the original" do
        original_db = Hijacker::Database.current
        Hijacker.should_receive(:connect).exactly(Database.with_responsive_hosts.size + 1).times
        Database.connect_each {}

        Hijacker::Database.current.should == original_db
      end

      it "eats invalid database errors" do
        Hijacker.stub(:connect).and_raise(Hijacker::InvalidDatabase.new("doesntmatter"))
        expect { Database.connect_each {|db| } }.not_to raise_error
      end

      it "eats mysql-specific errors for missing databases" do
        [Mysql::Error, Mysql2::Error].each do |klass|
          exception = klass.new("Unknown database 'fake'")
          exception.errno = 1049
          Hijacker.stub(:connect).and_raise(exception)
          expect { Database.connect_each {} }.to_not raise_error
        end
      end

      it "does not eat unrelated mysql-specific databases" do
        [Mysql::Error, Mysql2::Error].each do |klass|
          exception = klass.new("WAT")
          exception.errno = 2000
          Hijacker.stub(:connect).and_raise(exception)
          expect { Database.connect_each {} }.to raise_error(klass)
        end
      end

      it "does not raise exception when attempting to connect to original database" do
        allow(Hijacker).to receive(:current_client).and_return 'crystal_test'
        expect { Database.connect_each([]) {} }.to_not raise_error
      end
    end
  end
end
