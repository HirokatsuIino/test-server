# == Schema Information
#
# Table name: notification_mails
#
#  id          :integer          not null, primary key
#  company_id  :integer
#  employee_id :integer
#  class_name  :string(255)
#  method_name :string(255)
#  body_text   :text(65535)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class NotificationMail < ActiveRecord::Base
  belongs_to :employee
  belongs_to :company
end
