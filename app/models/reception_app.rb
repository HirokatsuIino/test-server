# == Schema Information
#
# Table name: reception_apps
#
#  id          :integer          not null, primary key
#  office_id   :integer          not null
#  uid         :string(255)      not null
#  ipad_uuid   :string(255)      not null
#  app_version :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class ReceptionApp < ActiveRecord::Base
  include Uid

  belongs_to :office, required: true

  validates :ipad_uuid,
    presence: true

end
