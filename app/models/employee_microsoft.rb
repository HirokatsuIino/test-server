# == Schema Information
#
# Table name: employee_microsofts
#
#  id          :integer          not null, primary key
#  employee_id :integer
#  auth_hash   :text(65535)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class EmployeeMicrosoft < ActiveRecord::Base
  belongs_to :employee

  serialize :auth_hash

  def self.save_token employee, token
  	microsoft_employee = self.find_by id: employee.id
  	if microsoft_employee
  		employee.update_attributes! auth_hash: token
  	else
  		employee.create_employee_microsoft!(auth_hash: token)
  	end
  end
end
