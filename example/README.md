# Example Multi Host Setup

## To run tests

1. Edit the my.cnf absolute paths to point to your local copy.
2. Run `mysqld_multi --defaults-file=my.cnf stop 11-13` from the example
   dir.
3. Run `./create_dbs.rb` to create databases
4. Run `./test.rb` to run tests

## TODO

Create rootschema db in mysql11
Create client dbs on mysql11, mysql12 and mysql13
Write test script which connects to each client db and does stuff
Test script checks to see if the databases exist, if they don't, run the
create databases command to create the root and client dbs.
