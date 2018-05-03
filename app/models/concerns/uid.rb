module Uid
  extend ActiveSupport::Concern

  included do
    before_validation :generate_uid, on: :create
    validates :uid,
      presence: true,
      uniqueness: { case_sensitive: false }
  end

  private

  def generate_uid
    self.uid ||= SecureRandom.uuid
  end
end
