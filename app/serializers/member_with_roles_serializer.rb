class MemberWithRolesSerializer < ActiveModel::Serializer
  attributes :uid,
    :email,
    :name,
    :name_reading,
    :phone_no,
    :icon_uri,
    :roles

  def icon_uri
    object.icon_uri || 'https://kitayon.co/images/default_icon.jpg'
  end

  def roles
    if @options.try(:[], :office_id)
      ActiveModel::Serializer::Adapter::Json.new(
        OfficeMemberSerializer.new(object.office_members.to_a.find { |om| om.office_id == @options[:office_id] })
      ).serializable_hash[:office_member]
    end
  end
end
