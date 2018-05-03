# == Schema Information
#
# Table name: chats
#
#  id                  :integer          not null, primary key
#  uid                 :string(255)      not null
#  name                :string(255)      not null
#  logo                :string(255)
#  label_api_ja        :string(255)
#  label_api_en        :string(255)
#  label_mention_to_ja :string(255)
#  label_mention_to_en :string(255)
#  label_mention_in_ja :string(255)
#  label_mention_in_en :string(255)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#

class Chat < ActiveRecord::Base
  include Uid

  has_many :companies_chats
  has_many :companies, :through => :companies_chat

  validates :uid,
    presence: true,
    uniqueness: { case_sensitive: false }
end
