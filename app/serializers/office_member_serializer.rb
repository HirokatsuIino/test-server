# == Schema Information
#
# Table name: office_members
#
#  id         :integer          not null, primary key
#  office_id  :integer          not null
#  member_id  :integer          not null
#  general    :boolean          default(FALSE)
#  admin      :boolean          default(FALSE)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class OfficeMemberSerializer < ActiveModel::Serializer
  attributes :admin, :general
end
