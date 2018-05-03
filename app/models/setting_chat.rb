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

class SettingChat < ActiveRecord::Base
  include Uid
  include Mslack
  include Chatwork

  belongs_to :company
  belongs_to :chat

  def enable_group_notifier?
    chat_id == 1 && slack_api_token
  end

  def is_using_slack_app?
    self.token.present? && !self.token.include?('https')
  end
end
