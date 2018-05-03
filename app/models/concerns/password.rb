module Password
  extend ActiveSupport::Concern

  included do
    before_validation :generate_password, on: :create
    validates :password,
      presence: :true,
      uniqueness: { case_sensitive: false }
  end

  private

  def generate_password
    self.password ||= SecureRandom.urlsafe_base64(8)
  end
end
