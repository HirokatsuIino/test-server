# == Schema Information
#
# Table name: setting_customs
#
#  id                   :integer          not null, primary key
#  uid                  :string(255)
#  chat_id              :integer
#  setting_app_id       :integer
#  active               :boolean
#  recording            :boolean
#  input_name           :boolean
#  input_company        :boolean
#  input_number         :boolean
#  text                 :string(255)
#  text_en              :string(255)
#  msg                  :string(255)
#  msg_en               :string(255)
#  email_to             :string(255)
#  mention_in           :string(255)
#  slack_group          :boolean          default(FALSE), not null
#  slack_group_id       :string(255)
#  button_type          :integer          default(0), not null
#  board_msg            :string(255)
#  board_msg_en         :string(255)
#  admission            :boolean          default(FALSE), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  fb_workplace_user_id :string(255)
#  workchat             :boolean
#  timeline             :boolean          default(TRUE)
#

class SettingCustomSerializer < ActiveModel::Serializer
  attributes :uid, :active, :recording, :input_name, :input_company, :input_number, :email_to, :msg, :msg_en, :text, :text_en, :mention_in, :chat, :show_user_groups, :slack_group, :slack_group_id, :custom_mentions, :button_type, :board_msg, :board_msg_en, :admission, :fb_workplace_user_id

  def chat
    object.chat
  end

  def show_user_groups
    setting_chat = object.company.get_setting_chat('Slack')
    !setting_chat.slack_api_token.nil? || (!setting_chat.token.nil? && !setting_chat.token.include?('https'))
  end

  def custom_mentions
    object.custom_mentions
  end
end
