# == Schema Information
#
# Table name: companies_chats
#
#  id         :integer          not null, primary key
#  uid        :string(255)      not null
#  company_id :integer          not null
#  chat_id    :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class CompaniesChat < ActiveRecord::Base
  include Uid

  belongs_to :company
  belongs_to :chat
end
