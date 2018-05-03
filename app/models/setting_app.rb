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

class SettingApp < ActiveRecord::Base
  include Uid
  mount_uploader :logo_url, LogoUploader
  mount_uploader :bg_url, BgUploader
  mount_uploader :admission_url, AdmissionUploader

  belongs_to :company
  has_many :setting_chats, through: :company
  has_many :setting_customs
  has_many :visitors

  validate :theme_choices
  validate :validate_rgb

  before_create :set_default_monitor_time

  def theme_choices
    theme == 'Light' || theme == 'Dark'
  end

  def validate_rgb
    unless /^([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/i === bg_rgb
      bg_rgb = nil
    end
  end

  def disable_setting_custom_admissions
    setting_customs.update_all(admission: false)
  end

  def set_default_monitor_time
    # in case of Japan
    self.monitor_begin_at = Time.parse("09:00:00 JST")
    self.monitor_end_at = Time.parse("20:00:00 JST")
  end
end
