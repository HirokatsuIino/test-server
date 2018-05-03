# == Schema Information
#
# Table name: visitors
#
#  id                :integer          not null, primary key
#  uid               :string(255)
#  notifier_type     :integer
#  company_id        :integer
#  employee_id       :integer
#  appointment_id    :integer
#  setting_custom_id :integer
#  setting_app_id    :integer
#  display           :boolean
#  name              :string(255)
#  company_name      :string(255)
#  number            :integer
#  email             :string(255)
#  phone_no          :string(255)
#  custom_label      :string(255)
#  custom_label_en   :string(255)
#  tablet_location   :string(255)
#  visited_at        :datetime
#  checked_out_at    :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#

class VisitorSerializer < ActiveModel::Serializer
  attributes :uid, :name, :company_name, :number, :visited_at, :employee_uid, :employee_name, :kind, :checked_out_at, :tablet_location, :display

  def employee_uid
    Employee.find_by_id(object.employee_id).try(:uid)
  end

  def employee_name
    Employee.find_by_id(object.employee_id).try(:name)
  end

  # we need this for some unknown bug
  def display
    object.display
  end

  def visited_at
    object.visited_at.try(:utc)
  end

  def kind
    kind = object.custom_label || '担当者検索'
    kind = "受付コード: #{object.appointment.code}" if object.appointment.try(:code)
    kind
  end
end
