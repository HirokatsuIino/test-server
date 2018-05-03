class OfficeWithCompanySerializer < ActiveModel::Serializer
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

  has_one :company

  def logo_uri
    object.logo_uri || 'https://kitayon.co/images/default_logo.jpg'
  end
end
