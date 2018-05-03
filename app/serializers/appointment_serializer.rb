# == Schema Information
#
# Table name: appointments
#
#  id          :integer          not null, primary key
#  uid         :string(255)
#  appo_type   :integer          default(0)
#  employee_id :integer
#  title       :string(255)
#  description :text(65535)
#  code        :string(255)
#  code_only   :boolean          default(FALSE), not null
#  begin_date  :date
#  begin_at    :datetime
#  end_date    :date
#  end_at      :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  edited      :boolean          default(FALSE), not null
#  company_id  :integer
#  place       :string(255)
#  eid         :string(255)
#  gc_int      :boolean          default(FALSE), not null
#  calendar_id :string(255)
#  resource_id :string(255)
#  display     :boolean          default(TRUE), not null
#  outlook     :boolean
#

class AppointmentSerializer < ActiveModel::Serializer
  attributes :uid, :appo_type, :employee_id, :employee_name, :title, :begin_date, :begin_at, :end_date, :end_at, :edited, :place, :visitors, :hosts, :code, :code_only, :display, :is_host, :is_integrated, :resource_id

  def employee_name
    Employee.find(object.employee_id).name
  end

  # we need this for some unknown bug
  def display
    object.display
  end

  def visitors
    object.visitors
  end

  def hosts
    object.hosts
  end

  def is_host
    object.hosts.include?(scope)
  end

  def is_integrated
    object.resource_id.present? && object.eid.present?
  end
end
