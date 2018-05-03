# == Schema Information
#
# Table name: appointments_hosts
#
#  id             :integer          not null, primary key
#  appointment_id :integer
#  employee_id    :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#

class AppointmentsHost < ActiveRecord::Base
  belongs_to :appointment
  belongs_to :host,
    class_name: 'Employee', foreign_key: :employee_id, required: true
end
