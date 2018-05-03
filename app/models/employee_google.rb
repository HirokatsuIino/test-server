# == Schema Information
#
# Table name: employee_googles
#
#  id          :integer          not null, primary key
#  employee_id :integer
#  calendar_id :string(255)
#  auth_hash   :text(65535)
#  expiry_date :date
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class EmployeeGoogle < ActiveRecord::Base
  belongs_to :employee

  serialize :auth_hash

  def integrated?
    !!expiry_date
  end

  def expired?
    return true unless expiry_date.present?
    expiry_date <= Time.current
  end
end
