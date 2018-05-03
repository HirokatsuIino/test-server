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

class OfficeSerializer < ActiveModel::Serializer
  attributes :uid,
    :name,
    :country,
    :zipcode,
    :address,
    :phone_no,
    :latitude,
    :longitude,
    :time_zone,
    :language,
    :logo_uri

  def logo_uri
    object.logo_uri || 'https://kitayon.co/images/default_logo.jpg'
  end
end
