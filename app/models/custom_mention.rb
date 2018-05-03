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

class CustomMention < ActiveRecord::Base
  belongs_to :setting_custom
  before_save :remove_slack_mention!

  private

  def remove_slack_mention!
    if self.mention_to
      if self.mention_to.include?("@")
        self.mention_to.delete!("@")
      end
    end
  end
end
