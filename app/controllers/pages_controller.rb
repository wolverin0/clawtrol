class PagesController < ApplicationController
  allow_unauthenticated_access
  redirect_authenticated_users
  layout "home"
  def home
  end
end
