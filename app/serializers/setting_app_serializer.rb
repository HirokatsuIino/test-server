# == Schema Information
#
# Table name: setting_apps
#
#  id                    :integer          not null, primary key
#  uid                   :string(255)
#  company_id            :integer
#  tablet_uid            :string(255)
#  tablet_location       :string(255)
#  theme                 :string(255)
#  logo_url              :string(255)
#  bg_url                :string(255)
#  bg_rgb                :string(255)
#  bg_default            :integer          default(1)
#  text                  :string(255)
#  text_en               :string(255)
#  done_text             :string(255)
#  done_text_en          :string(255)
#  code                  :boolean          default(TRUE), not null
#  search                :boolean          default(FALSE), not null
#  input_name            :boolean
#  input_company         :boolean
#  input_number_code     :boolean
#  input_number_search   :boolean
#  tel_error             :string(255)
#  admission             :boolean          default(FALSE), not null
#  admission_url         :string(255)
#  monitoring            :boolean
#  monitoring_chat_id    :integer
#  monitoring_mention_in :string(255)
#  monitor_begin_at      :time
#  monitor_end_at        :time
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#

class SettingAppSerializer < ActiveModel::Serializer
  attributes :uid, :tablet_uid, :tablet_location, :theme, :logo_url, :bg_url, :bg_rgb , :bg_default, :text, :text_en, :done_text, :done_text_en, :code, :search, :input_name, :input_company, :input_number_search, :input_number_code, :tel_error, :admission_url, :admission, :is_enterprise,:monitoring, :monitoring_chat_id, :monitoring_mention_in, :monitor_begin_at, :monitor_end_at 

  has_many :setting_chats do
    object.setting_chats.where(active: true)
  end
  has_many :setting_customs


  def is_enterprise
    object.company.upgraded_plan?
  end
end
