class HomeSerializer < ActiveModel::Serializer
  attributes :name, :zipcode, :address1, :address2, :phone_no, :employees_count, :visitors_count, :plan_status, :active_app, :available_count, :app_info, :employee_visitor_read

  def employees_count
    object.employees.count
  end

  def visitors_count
    object.visitors.where.not(visited_at: nil).where(created_at: Time.now.all_month).count
  end

  def available_count
    object.setting_apps.count
  end

  def app_info
    object.setting_apps.map(&:tablet_location)
  end

end
