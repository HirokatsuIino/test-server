class SettingsSerializer < ActiveModel::Serializer

  has_many :setting_apps
  has_many :setting_customs

  def chat
  	Chat.find(object.chat_id)
  end
end
