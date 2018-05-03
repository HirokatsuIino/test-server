# == Schema Information
#
# Table name: appointments
#
#  id          :integer          not null, primary key
#  uid         :string(255)
#  appo_type   :integer          default(0)
#  employee_id :integer
#  title       :string(255)
#  description :text(65535)
#  code        :string(255)
#  code_only   :boolean          default(FALSE), not null
#  begin_date  :date
#  begin_at    :datetime
#  end_date    :date
#  end_at      :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  edited      :boolean          default(FALSE), not null
#  company_id  :integer
#  place       :string(255)
#  eid         :string(255)
#  gc_int      :boolean          default(FALSE), not null
#  calendar_id :string(255)
#  resource_id :string(255)
#  display     :boolean          default(TRUE), not null
#  outlook     :boolean
#  status      :integer          default(0), not null
#  provisional_eids      :text(65535)
#

class Appointment < ActiveRecord::Base
  include Uid

  # 招待状を作成した社員
  belongs_to :sender,
    class_name: 'Employee', foreign_key: :employee_id, required: true
  belongs_to :company

  # 招待に参加する個人の情報
  has_many :visitors, inverse_of: :appointment, dependent: :destroy
  accepts_nested_attributes_for :visitors, allow_destroy: true
  has_many :appointments_hosts, foreign_key: :appointment_id
  has_many :hosts, :through => :appointments_hosts, dependent: :destroy

  enum appo_type: [:onetime, :irregular, :regular]
  
  before_validation :prepare_attributes
  before_update :update_attributes

  validates :code, presence: true, length: { is: 6 }
  validates_date :begin_date, on: :create, on_or_after: :today
  validates_date :begin_date, on: :update, on_or_after: :today
  validates_date :end_date, on: :create, on_or_after: :today
  validates_date :end_date, on: :update, on_or_after: :today
  validates_datetime :end_date, on_or_after: :begin_date
  validates_datetime :begin_at, on: :create, after: :now, allow_blank: true
  validates_datetime :begin_at, on: :update, after: :now, allow_blank: true
  validates_datetime :end_at, after: :begin_at, allow_blank: true

  enum status: [:provisional, :confirm]

  scope :after_current_time, -> {
    where('begin_at > ?', Time.zone.now).order(:begin_at)
  }

  scope :available_irregular_apppointmnet, -> {
    where('end_date > ?', Time.zone.now).order(:end_date)
  }
  # onetimeでかつcodeが有効なappo(前後24時間)
  scope :not_expiry_onetime_code, -> {
    where(appo_type: 0).
      where('begin_at > ? AND begin_at < ?', Time.current.yesterday, Time.current.tomorrow)
  }
  # irregularでかつcodeが有効なappo(begin_dateとend_dateが今日に含まれる)
  scope :not_expiry_irregular_code, -> {
    where(appo_type: 1).
      where('begin_date <= ? AND end_date >= ?', Date.today, Date.today)
  }

  def valid_date?
    if self.onetime?
      begin_at > Time.current.beginning_of_day && begin_at < Time.current.end_of_day
    else
      (begin_date..end_date).cover?(Time.now)
    end
  end

  def valid_code?
    if self.onetime?
      true # TODO: enable to set code manually for onetime appointment
    else
      appointments = self.company.appointments.where('begin_date <= ? AND end_date >= ?', self.begin_date, self.end_date)
      codes = appointments.pluck(:code)
      !codes.include?(self.code.to_s)
    end
  end

  def update_provisional
    self.update(status: "provisional")
  end

  def update_confirm
    self.update(status: "confirm")
  end

  private

  def prepare_attributes
    if self.onetime?
      if begin_at
        self.begin_date ||= begin_at.in_time_zone(Rails.application.config.time_zone).to_date
        self.end_date ||= end_at.in_time_zone(Rails.application.config.time_zone).to_date
      end
    end
    self.code ||= generate_code if begin_date
  end

  def update_attributes
    if self.onetime?
      self.begin_date = begin_at.in_time_zone(Rails.application.config.time_zone).to_date
      self.end_date = end_at.in_time_zone(Rails.application.config.time_zone).to_date
    end
  end

  def generate_code
    # 予定日の前後日で被らないコードを発行する
    day = begin_date.to_s.split('-').last
    last_digit = day.to_s.split('').last
    if day == '31'
      last_digit = [2, 3, 4, 5, 6, 7, 8, 9].sample.to_s
    end
    ("%05d" % SecureRandom.random_number(100_000)) << last_digit
  end
end
