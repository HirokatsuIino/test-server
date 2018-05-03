# == Schema Information
#
# Table name: contact_categories
#
#  id            :integer          not null, primary key
#  label_name    :string(255)      not null
#  label_name_en :string(255)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

class ContactCategory < ActiveRecord::Base
end
