# == Schema Information
#
# Table name: employee_mentions
#
#  id          :integer          not null, primary key
#  chat_id     :integer
#  employee_id :integer
#  mention_in  :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class EmployeeMentionSerializer < ActiveModel::Serializer
  attributes :mention_in, :chat

  def chat
  	object.chat
  end
end
