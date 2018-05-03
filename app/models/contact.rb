# == Schema Information
#
# Table name: contacts
#
#  id                  :integer          not null, primary key
#  employee_id         :integer
#  contact_type        :integer          default(0)
#  company_name        :string(255)      not null
#  department          :string(255)
#  name                :string(255)      not null
#  email               :string(255)      not null
#  phone_no            :string(255)      not null
#  address             :text(65535)
#  chat_tool           :string(255)
#  scheduler           :string(255)
#  employee_number     :string(255)
#  uid                 :string(255)      not null
#  body                :text(65535)
#  contact_category_id :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#

class Contact < ActiveRecord::Base
  include Uid
  belongs_to :employee
  belongs_to :category, :class_name => :ContactCategory, :foreign_key => "contact_category_id"

  enum contact_type: [:normal, :document]
end
