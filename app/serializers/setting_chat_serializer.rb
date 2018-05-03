# == Schema Information
#
# Table name: setting_chats
#
#  id                       :integer          not null, primary key
#  uid                      :string(255)
#  company_id               :integer
#  chat_id                  :integer
#  active                   :boolean
#  primary                  :integer          default(0), not null
#  authorized               :boolean          default(FALSE), not null
#  token                    :text(65535)
#  slack_api_token          :string(255)
#  msg                      :string(255)
#  msg_en                   :string(255)
#  mention_in               :string(255)
#  mention_to               :string(255)
#  cw_account_id            :integer
#  slack_group              :boolean          default(FALSE), not null
#  timeline                 :boolean          default(TRUE)
#  workchat                 :boolean
#  line_works_bot           :integer
#  line_works_bot_name      :text(65535)
#  line_works_bot_photo_url :text(65535)
#  line_works_app_id        :text(65535)
#  line_works_consumer_key  :text(65535)
#  slack_group_id           :string(255)
#  recurrent                :boolean          default(FALSE)
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#

class SettingChatSerializer < ActiveModel::Serializer
  attributes :uid, :active, :token, :msg, :msg_en, :mention_in, :mention_to, :cw_account_id, :chat, :slack_api_token, :first_flag, :reception_mail_allowed, :authorized, :line_works_bot_name, :line_works_bot_photo_url, :line_works_bot, :line_works_app_id, :line_works_consumer_key, :recurrent

  def chat
  	Chat.find(object.chat_id)
  end

  def reception_mail_allowed
    object.company.reception_mail_allowed
  end

  def first_flag
  	@instance_options[:first_flag]
  end
end
