# Include hook code here
require 'hijacker'
require 'hijacker/controller_methods'

class ActionController::Base
  include Hijacker::ControllerMethods::Instance
end
