class MemberDetailSerializer < ActiveModel::Serializer
  attributes :uid,
    :email,
    :name,
    :name_reading,
    :phone_no,
    :icon_uri,
    :offices

  has_one :company

  def offices
    object.office_members.eager_load(:office).map do |role|
      ActiveModel::Serializer::Adapter::Json.new(
        OfficeSerializer.new(role.office)
      ).serializable_hash[:office]
      .merge general: role.general, admin: role.admin
    end
  end
end
