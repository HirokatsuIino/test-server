class Api::Offices::ReceptionAppsController < ApplicationController
  before_action :prepare_office
  def index
    render json: @office.reception_apps.page(params[:page]).per(params[:per]),
      serializer: PaginatedSerializer
  end
  def create
    fail NotImplementedError
  end
  def destroy
    fail NotImplementedError
  end
end
