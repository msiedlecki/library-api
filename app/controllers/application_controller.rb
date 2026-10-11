class ApplicationController < ActionController::API
  include ErrorHandling

  wrap_parameters false
end
