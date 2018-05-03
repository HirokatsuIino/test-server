class Api::OfficesController < ApplicationController
  before_action :login_employee_only!, only: [:create]
  before_action :admin!, only: :create
  before_action :prepare_company
  before_action :prepare_office, only: %i(show update)

  def specified
    render json: @company.offices.first, serializer: OfficeWithCompanySerializer
  end
  def index
    render json: @company.offices.page(params[:page]).per(params[:per]),
      serializer: PaginatedSerializer
  end

  def create
    @office = Office.new(office_params)

    if @office.save!
      render json: @office, status: 201
    else
      render json: {},  status: :unprocessable_entitiy
    end
  end

  def update
    @office.update!(office_params)
    render json: @office
  end
  def destroy
    fail NotImplementedError
  end

  private

  def office_params
    params.require(:office).permit(
      :name,
      :zipcode,
      :phone_no,
      :latitude,
      :longitude,
      :time_zone,
      :language,
      :company_id
    )
  rescue
    {}
  end
end
