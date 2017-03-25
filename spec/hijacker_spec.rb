require "spec_helper"
require 'hijacker/redis_keys'
require 'support/redis_keys_module'

describe Hijacker do
  include RedisKeysModule::Helper
  Hijacker.logger.level = 100 # keep the logging quiet during the tests


  let(:hosted_environments) { %w[staging production] }

  before(:each) do
    Hijacker.config = {
      :hosted_environments => hosted_environments
    }

    $hijacker_redis.del('test:hijacker:unresponsive-dbhosts:threshold-count')
    $hijacker_redis.del('test:hijacker:unresponsive-dbhosts')
    $hijacker_redis.del('test:hijacker:unresponsive-dbhost-ids')
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
        subject.stub(:root_connection).and_return(double(:config => {}))
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
          ::ActiveRecord::Base.connection.query_cache_enabled.should eq(true)
        end

        it "calls cache on the connection" do
          ::ActiveRecord::Base.connection.should_receive(:cache)
          subject.connect('master_db')
        end
      end

      context "after_hijack call specified" do
        let(:spy) { double.as_null_object }
        before(:each) do
          Hijacker.config.merge!(:after_hijack => spy)
        end

        it "calls the callback" do
          spy.should_receive(:call)
          subject.connect('master_db')
        end
      end

      context "uses scope to filter out unresponsive hosts for #connect_each" do
        let!(:create_unresponsive_host) { Hijacker::Host.create!(:hostname => "bad.host", :port => 9999) }
        let(:unresponsive_host) { Hijacker::Host.where(:port => 9999).first }
        
        let!(:apple) { Hijacker::Database.create!(:database => "apple", :host_id => host.id) }
        let!(:cherry) { Hijacker::Database.create!(:database => "cherry", :host_id => unresponsive_host.id) }
        let!(:grape) { Hijacker::Database.create!(:database => "grape", :host_id => host.id) }

        let!(:check_connection_without_patch) {
          class << Hijacker
            alias_method :check_connection_without_patch, :check_connection
            attr_accessor :current_config
          end
        }
        let!(:establish_connection_to_database) {
          class << Hijacker
            alias_method :establish_connection_to_database_without_patch, :establish_connection_to_database
          end
        }

        before do

          # Obviously, the tests which use Sqlite3 will never raise a Mysql2::Error, but the production code
          # will be using Mysql.
          #
          allow(Hijacker).to receive(:check_connection){
            Hijacker.instance_exec do
              raise Mysql2::Error.new "Can't connect to MySQL server on '#{current_config['host']}' (111)" if current_config['database'] == 'cherry'
              check_connection_without_patch
            end
          }
          
          # Sqlite ActiveRecord::Base.connection.config is different from that for MySql, 
          # so for testing, we need to create a handle that allows us to introspect the 
          # configuration so that we can create a spy to look for a particular
          # host and treat it as though it were unresponsive
          #
          allow(Hijacker).to receive(:establish_connection_to_database){ |database, slave_connection = false|
            Hijacker.instance_exec do
              @current_config = connection_config(database, slave_connection)
              ::ActiveRecord::Base.establish_connection(current_config)
            end
          }
        end

        # Expects there to be no unhandled exceptions raised
        it "iterates through all responsive hosts" do
          Hijacker::Database.connect_each do |db|
            ActiveRecord::Base.connection.execute("select 'asdf'")
          end
        end

        it "skips and processes all other unaffected databases" do
          @db_cnt = 0
          Hijacker::Database.connect_each do |db|
            ActiveRecord::Base.connection.execute("select 'asdf'")
            @db_cnt += 1
          end

          expect(@db_cnt).to eq 3
        end

        it "records one db host as unresponsive" do
          Hijacker::Database.connect_each do |db|
            ActiveRecord::Base.connection.execute("select 'asdf'")
          end

          expect($hijacker_redis.hgetall('test:hijacker:unresponsive-dbhosts')).to eq({"localhost"=>"0", "bad.host"=>"1"})
        end

        it "skips db hosts that have hit the count threshold" do
          $hijacker_redis.hset('test:hijacker:unresponsive-dbhosts', 'bad.host', 10)

          responsive_dbhosts = []
          Hijacker::Database.connect_each do |db|
            responsive_dbhosts << db
          end

          expect(responsive_dbhosts).to eq(["master_db", "apple", "grape"])
        end
      end

      context "mysql error handling" do
        let!(:host2) { Hijacker::Host.create!(:hostname => "tree") }
        let!(:host3) { Hijacker::Host.create!(:hostname => "vine") }
        let!(:host4) { Hijacker::Host.create!(:hostname => "bush") }
        let!(:host5)  { Hijacker::Host.create!(:hostname => "missing") }

        let!(:apple) { Hijacker::Database.create!(:database => "apple", :host_id => host2.id) }
        let!(:cherry) { Hijacker::Database.create!(:database => "cherry", :host_id => host2.id) }
        let!(:orange) { Hijacker::Database.create!(:database => "orange", :host_id => host2.id) }
        let!(:lemon) { Hijacker::Database.create!(:database => "lemon", :host_id => host2.id) }
        let!(:polmegranite) { Hijacker::Database.create!(:database => "polmegranite", :host_id => host4.id) }
        let!(:boysenberry) { Hijacker::Database.create!(:database => "boysenberry", :host_id => host3.id) }
        let!(:grape) { Hijacker::Database.create!(:database => "grape", :host_id => host3.id) }
        let!(:tomato) { Hijacker::Database.create!(:database => "tomato", :host_id => host5.id) }

        let(:error_table) { HashWithIndifferentAccess.new({
          polmegranite: (Mysql2::Error.new "Can't connect to MySQL server on '#{polmegranite.host.hostname}' (111)"), # Hijacker::MYSQL_UNRESPONSIVE_HOST
          tomato: (Mysql2::Error.new "Unknown MySQL server host '#{tomato.host.hostname}'"), # Hijacker::MYSQL_UNKNOWN_HOST
          peach: (Mysql2::Error.new "Unknown database 'peach'"), # Hijacker::MYSQL_UNKNOWN_DB
          grape: (Mysql2::Error.new "Access denied for user 'crystal'@'#{polmegranite.host.hostname}'"), # Hijacker::MYSQL_ACCESS_DENIED
          cherry: (Mysql2::Error.new "Some other MySQL error for 'cherry' on '#{cherry.host.hostname}'") # Hijacker::MYSQL_GENERIC
        })}

        let!(:establish_connection_to_database) {
          class << Hijacker
            alias_method :establish_connection_to_database_without_patch, :establish_connection_to_database
          end
        }
        
        let!(:check_connection_without_patch) {
          class << Hijacker
            alias_method :check_connection_without_patch, :check_connection
            attr_accessor :current_config
          end
        }

        before(:each) do
          allow(Hijacker).to receive(:establish_connection_to_database){ |database, slave_connection = false|
            Hijacker.instance_exec do
              @current_config = connection_config(database, slave_connection)
              ::ActiveRecord::Base.establish_connection(current_config)
            end
          }
          
          allow(Hijacker).to receive(:check_connection) do
            error = error_table[Hijacker.current_config['database']]
            raise error unless error.nil?
          end

          @counts = {
            Hijacker::MYSQL_GENERIC => 0, 
            Hijacker::MYSQL_ACCESS_DENIED => 0, 
            Hijacker::MYSQL_UNKNOWN_DB => 0, 
            Hijacker::MYSQL_UNKNOWN_HOST => 0, 
            Hijacker::MYSQL_UNRESPONSIVE_HOST => 0
          }
        end

        it "handles different kinds of mysql errors" do
          Hijacker::Database.connect_each do |db|
            ActiveRecord::Base.connection.execute("select 'asdf'")
          end
        end

        it "exposes unresponsive host error" do
          begin
            Hijacker::Database.connect_each(['polmegranite'], {validate_connections: false}) do |db|
              ActiveRecord::Base.connection.execute("select 'asdf'")
            end
          rescue => e
            @counts[e.class] += 1
          end

          expect(@counts).to eq( @counts.merge({Hijacker::MYSQL_UNRESPONSIVE_HOST => 1}) )
        end

        it "exposes unknown host error" do
          begin
            Hijacker::Database.connect_each(['tomato'], {validate_connections: false}) do |db|
              ActiveRecord::Base.connection.execute("select 'asdf'")
            end
          rescue => e
            @counts[e.class] += 1
          end

          expect(@counts).to eq( @counts.merge({Hijacker::MYSQL_UNKNOWN_HOST => 1}) )
        end

        it "exposes unknown database error" do
          begin
            Hijacker::Database.connect_each(['peach'], {validate_connections: false}) do |db|
              ActiveRecord::Base.connection.execute("select 'asdf'")
            end
          rescue => e
            @counts[e.class] += 1
          end

          expect(@counts).to eq( @counts.merge({Hijacker::MYSQL_UNKNOWN_DB => 1}) )
        end

        it "exposes access denied error" do
          begin
            Hijacker::Database.connect_each(['grape'], {validate_connections: false}) do |db|
              ActiveRecord::Base.connection.execute("select 'asdf'")
            end
          rescue => e
            @counts[e.class] += 1
          end

          expect(@counts).to eq( @counts.merge({Hijacker::MYSQL_ACCESS_DENIED => 1}) )
        end

        it "exposes access denied error" do
          begin
            Hijacker::Database.connect_each(['cherry'], {validate_connections: false}) do |db|
              ActiveRecord::Base.connection.execute("select 'asdf'")
            end
          rescue => e
            @counts[e.class] += 1
          end

          expect(@counts).to eq( @counts.merge({Hijacker::MYSQL_GENERIC => 1}) )
        end
      end
      
      context "should record requests to unresponsive hosts" do
        before(:each) do
          @unresponsive_host = Hijacker::Host.create!({hostname: 'bogus'})
          @junk_database = Hijacker::Database.create!({database: 'junk', host_id: @unresponsive_host.id})

          $hijacker_redis.del(redis_keys(:unresponsive_dbhost_count_threshold))
          @prev_threshold_count = $hijacker_redis.get('test:hijacker:unresponsive-dbhosts:threshold-count')
          $hijacker_redis.set('test:hijacker:unresponsive-dbhosts:threshold-count', 3)
          $hijacker_redis.del('test:hijacker:unresponsive-dbhosts')
        end

        after(:each) do
          @junk_database.destroy
          @unresponsive_host.destroy
          $hijacker_redis.set('test:hijacker:unresponsive-dbhosts:threshold-count', @prev_threshold_count)
        end

        it "determines a host is unresponsive" do
          expect(Hijacker).to receive(:dbhost_available?).and_return false
          expect{subject.connect('junk')}.to raise_error(Hijacker::UnresponsiveHostError)
        end

        it "keeps count of failed attempts to connect" do
          allow(Hijacker).to receive(:check_connection).and_raise Mysql2::Error.new "Can't connect to MySQL server on '#{@unresponsive_host.hostname}' (111)"

          # one call to connection_config when attempting to connect (3 times)
          #
          # one call to connection_config when simply trying to get the
          # connection information without checking for db host availability (4 times)
          #
          expect(Hijacker).to receive(:connection_config).exactly(7).times.and_call_original

          expect(subject.unresponsive_dbhost_count('bogus')).to eq 0
          expect(subject.dbhost_available?('bogus')).to be true

          # 1. unresponsive
          # 2. unresponsive
          # 3. unresponsive
          # 4. host is disabled; no futher connections will be entertained
          (1..4).each do
            begin
              subject.connect('junk')
            rescue
            end
          end

          expect(subject.unresponsive_dbhost_count('bogus')).to eq 3
          expect(subject.dbhost_available?('bogus')).to be false
        end

        it "resets count back to zero if successful connection is made before threshold is hit" do

          # Simulate 2 calls resulting in no response from db host followed by others that are successful
          # and once a successful call is found _before_ the threshold is met, the host counter is reset to 0
          @cnt = 0
          allow(Hijacker).to receive(:check_connection) do
            @cnt += 1
            raise Mysql2::Error.new "Can't connect to MySQL server on '#{@unresponsive_host.hostname}' (111)" if @cnt <= 2
          end

          expect(subject.unresponsive_dbhost_count('bogus')).to eq 0
          expect(subject.dbhost_available?('bogus')).to be true

          # 1. unresponsive
          # 2. unresponsive
          # 3. connection made; counter is reset
          (1..3).each do
            begin
              subject.connect('junk')
            rescue
            end
          end

          expect(subject.unresponsive_dbhost_count('bogus')).to eq 0
          expect(subject.dbhost_available?('bogus')).to be true
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
