module Hijacker
  class BaseModel < ActiveRecord::Base
    if Rails.env.test?
      establish_connection({
        adapter: 'mysql2',
        username: 'root',
        password: '',
        host: '127.0.0.1',
        database: 'crystal_test'
      })
    else
      establish_connection(:root)
    end

    self.abstract_class = true
  end
end
