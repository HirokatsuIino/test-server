# == Schema Information
#
# Table name: offices
#
#  id         :integer          not null, primary key
#  company_id :integer          not null
#  uid        :string(255)      not null
#  name       :string(255)      not null
#  country    :string(255)
#  zipcode    :string(255)
#  address    :string(255)
#  phone_no   :string(255)
#  latitude   :decimal(9, 6)
#  longitude  :decimal(9, 6)
#  time_zone  :string(255)      not null
#  language   :string(255)      not null
#  logo_uri   :text(65535)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Office < ActiveRecord::Base
  include Uid

  belongs_to :company, required: true

  has_many :reception_apps

  validates :name,
    presence: true
  validates :time_zone,
    presence: true,
    inclusion: { in: ActiveSupport::TimeZone::MAPPING.values }
  validates :language,
    presence: true,
    inclusion: { in: I18n.available_locales.map(&:to_s) }

  # action_message :all
end
