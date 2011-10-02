class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :default_format_json

  protected

  def default_format_json
    if(request.headers["HTTP_ACCEPT"].nil? &&
       params[:format].nil?)
      request.format = "json"
    end
  end
end
