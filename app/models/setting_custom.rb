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

class SettingCustom < ActiveRecord::Base
  include Uid
  include Chatwork

  belongs_to :setting_app
  delegate :company, :to => :setting_app
  belongs_to :chat
  has_many :custom_mentions
  enum button_type: { notification: 0, msg_board: 1 }

  # activeだと命名がよくないと怒られるので
  scope :turning, -> {
    where(active: true)
  }

  SLACK_COMMANDS = %w(channel group here everyone)

  def get_setting_chat(company)
    company.setting_chats.find_by(chat_id: self.chat.id)
  end

  def validate_slack_username(token, mention_to)
    return true if Rails.env.test?
    if token && !token.include?('https')
      return true if SLACK_COMMANDS.include?(mention_to)
      result = SlackApi.get_user_id(token, mention_to)
      return result[:ok] ? result[:slack_user_id] : false
    end
    return true
  end

  def update_slack_user_id(token)
    return true if Rails.env.test?
    if token && !token.include?('https')
      cm = self.custom_mentions.first # slack
      return true if SLACK_COMMANDS.include?(cm.mention_to)
      result = SlackApi.get_user_id(token, cm.mention_to)
      return false unless result[:ok]
      cm.update(slack_user_id: result[:slack_user_id]) if result[:ok]
    end
    return true
  end

end
