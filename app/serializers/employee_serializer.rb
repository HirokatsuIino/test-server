# == Schema Information
#
# Table name: employees
#
#  id                      :integer          not null, primary key
#  email                   :string(255)      default(""), not null
#  encrypted_password      :string(255)      default(""), not null
#  reset_password_token    :string(255)
#  reset_password_sent_at  :datetime
#  reset_password_allow    :boolean
#  remember_created_at     :datetime
#  sign_in_count           :integer          default(0), not null
#  current_sign_in_at      :datetime
#  last_sign_in_at         :datetime
#  current_sign_in_ip      :string(255)
#  last_sign_in_ip         :string(255)
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  uid                     :string(255)      not null
#  name                    :string(255)
#  name_reading            :string(255)
#  name_reading_search     :string(255)
#  phone_no                :string(255)
#  icon_uri                :string(255)
#  company_id              :integer
#  admin                   :boolean          default(FALSE)
#  admin_authority_token   :string(255)
#  admin_authority_sent_at :datetime
#  admin_authorized_at     :datetime
#  department              :string(255)
#  slack                   :string(255)
#  slack_user_id           :string(255)
#  provider                :string(255)      default("email"), not null
#  confirmation_token      :string(255)
#  confirmed_at            :datetime
#  confirmation_sent_at    :datetime
#  tokens                  :text(65535)
#  refresh_tokens          :text(65535)
#  unconfirmed_email       :string(255)
#  active                  :boolean          default(FALSE), not null
#  name_reading_en         :string(255)
#  first_name              :string(255)
#  last_name               :string(255)
#  cw_id                   :string(255)
#  cw_account_id           :integer
#  slack_sub               :string(255)
#  slack_user_id_sub       :string(255)
#  cw_id_sub               :string(255)
#  cw_account_id_sub       :integer
#  uqid                    :string(255)      not null
#  one_team                :text(65535)
#  one_team_sub            :text(65535)
#  facebook_workplace      :text(65535)
#  facebook_workplace_sub  :text(65535)
#  dingtalk                :text(65535)
#  dingtalk_sub            :text(65535)
#  line_works              :text(65535)
#  line_works_sub          :text(65535)
#  timeline                :boolean          default(TRUE)
#  workchat                :boolean
#  ms_teams                :text(65535)
#  ms_teams_sub            :text(65535)
#  fcm_id                  :text(65535)
#

class EmployeeSerializer < ActiveModel::Serializer
  attributes :uqid, :admin, :name, :name_reading, :first_name, :last_name, :name_reading_en, :email, :icon_uri, :department, :slack, :cw_id, :one_team, :active, :cw_account_id, :slack_sub, :cw_id_sub, :one_team_sub, :cw_account_id_sub, :facebook_workplace, :facebook_workplace_sub, :dingtalk, :dingtalk_sub, :line_works, :line_works_sub, :ms_teams, :ms_teams_sub

  has_many :mention_ins
  
end

