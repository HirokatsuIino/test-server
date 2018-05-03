# == Schema Information
#
# Table name: employee_notifications
#
#  id              :integer          not null, primary key
#  employee_id     :integer
#  notification_id :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  company_id      :integer
#

class EmployeeNotification < ActiveRecord::Base
  belongs_to :employee
  belongs_to :notification
  belongs_to :company
end
