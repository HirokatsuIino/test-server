# == Schema Information
#
# Table name: custom_mentions
#
#  id                :integer          not null, primary key
#  setting_custom_id :integer
#  mention_to        :string(255)
#  slack_user_id     :string(255)
#  cw_account_id     :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#

class CustomMentionSerializer < ActiveModel::Serializer
  attributes :id, :mention_to, :cw_account_id
end
