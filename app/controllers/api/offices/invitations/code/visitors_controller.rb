class Api::Offices::Invitations::Code::VisitorsController < ApplicationController
  before_action :prepare_invitation_from_code
  before_action :prepare_visitor, only: %i(update destroy)
  def index
    render json: @invitation.visitors
  end
  def create
    @visitor = @invitation.visitors.create! visitor_params
    render json: @visitor, status: :created
  end
  def update
    @visitor.update_attributes! visitor_params
    render json: @visitor
  end
  def destroy
    @visitor.destroy
    render json: {}
  end

  private

  def prepare_invitation_from_code
    @invitation ||= Office.find_by!(uid: params[:office_uid])
      .invitations
      .where(begin_date: params[:begin_date])
      .find_by!(code: params[:code])
  end

  def prepare_visitor
    @visitor ||= prepare_invitation_from_code.visitors.find_by!(id: params[:visitor_id])
    fail Errors::Forbidden if @visitor.visited_at
    @visitor
  end

  def visitor_params
    params.require(:visitor).permit(
      :name,
      :company_name,
      :email,
      :phone_no
    )
  rescue
    {}
  end
end
