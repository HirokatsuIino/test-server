# == Schema Information
#
# Table name: companies
#
#  id                        :integer          not null, primary key
#  uid                       :string(255)      not null
#  name                      :string(255)      not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  name_reading              :string(255)
#  name_reading_en           :string(255)      not null
#  zipcode                   :string(255)      not null
#  address1                  :string(255)
#  address2                  :string(255)      not null
#  phone_no                  :string(255)      not null
#  plan_status               :integer          default(0), not null
#  active_chat               :boolean          default(FALSE), not null
#  active_app                :boolean          default(FALSE), not null
#  active_employee           :boolean          default(FALSE), not null
#  admin_name                :string(255)
#  corporate_url             :string(255)
#  locale_code               :string(255)      default("ja"), not null
#  ec_sub_id                 :string(255)
#  tc_sub_id                 :string(255)
#  payment_type              :integer          default(0), not null
#  test_notifier             :boolean          default(FALSE), not null
#  trial_expired_at          :datetime         not null
#  tc_plan_id                :string(255)
#  ec_plan_id                :string(255)
#  csv_file                  :string(255)
#  reception_mail_allowed    :boolean          default(TRUE), not null
#  employee_visitor_read     :boolean          default(TRUE), not null
#  employee_visitor_download :boolean          default(FALSE), not null
#  salesforce_id             :string(255)
#

class CompanySerializer < ActiveModel::Serializer
  attributes :uid, :name, :name_reading, :name_reading_en, :zipcode, :address1, :address2, :phone_no, :plan_status, :count, :admin_name, :corporate_url, :reception_mail_allowed, :tablet_count, :employee_visitor_read, :employee_visitor_download, :locale_code

  #TODO masterのserialize修正後
  def count
    object.employees.count
  end
  #has_many :offices
  #has_many :employees

  def tablet_count
    object.setting_apps.count
  end

  # web v1 への影響を考慮しコメントアウト
  # def plan_status
  #   if object.plan_status == 'standard'
  #     'basic'
  #   elsif object.plan_status == 'enterprise'
  #     'business'
  #   else
  #     object.plan_status
  #   end
  # end
end
