# Example Multi Host Setup

## To run tests

1. Edit the my.cnf absolute paths to point to your local copy.
2. Run `mysqld_multi --defaults-file=my.cnf stop 11-14` from the example
   dir.
3. Run `./create_dbs.rb` to create databases
4. Run `./test.rb` to run tests
