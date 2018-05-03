# == Schema Information
#
# Table name: companies
#
#  id                        :integer          not null, primary key
#  uid                       :string(255)      not null
#  name                      :string(255)      not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  name_reading              :string(255)
#  name_reading_en           :string(255)      not null
#  zipcode                   :string(255)      not null
#  address1                  :string(255)
#  address2                  :string(255)      not null
#  phone_no                  :string(255)      not null
#  plan_status               :integer          default(0), not null
#  active_chat               :boolean          default(FALSE), not null
#  active_app                :boolean          default(FALSE), not null
#  active_employee           :boolean          default(FALSE), not null
#  admin_name                :string(255)
#  corporate_url             :string(255)
#  locale_code               :string(255)      default("ja"), not null
#  ec_sub_id                 :string(255)
#  tc_sub_id                 :string(255)
#  payment_type              :integer          default(0), not null
#  test_notifier             :boolean          default(FALSE), not null
#  trial_expired_at          :datetime         not null
#  tc_plan_id                :string(255)
#  ec_plan_id                :string(255)
#  csv_file                  :string(255)
#  reception_mail_allowed    :boolean          default(TRUE), not null
#  employee_visitor_read     :boolean          default(TRUE), not null
#  employee_visitor_download :boolean          default(FALSE), not null
#  salesforce_id             :string(255)
#

class Company < ActiveRecord::Base
  include Uid
  include Pay
  mount_uploader :csv_file, CsvUploader
  has_many :offices
  has_many :employees
  has_many :visitors
  has_many :companies_chats
  has_many :chats, :through => :companies_chats
  has_many :setting_chats
  has_many :setting_apps
  has_many :setting_customs, :through => :setting_apps
  has_one :setting_gc
  has_many :appointments
  has_many :notifications
  has_many :notification_mails
  has_many :employee_notifications

  validates :uid,
    presence: true,
    uniqueness: { case_sensitive: false }
  validates :name,
    presence: true
  validates :name_reading_en,
    presence: true
  validates :zipcode,
    presence: true
  validates :address1,
    presence: true
  validates :address2,
    presence: true
  validates :phone_no,
    presence: true

  # github:#1260 basicとbusinessは、Serializerでそれぞれstandard, enterpriseに置換
  enum plan_status: [:standard, :enterprise, :trial, :free, :premium]
  enum payment_type: [:free_price, :measured_price, :fixed_price, :invoice]

  before_validation :set_expired_at, on: :create

  PAYJP_EXCEPTIONS = [4, 738, 688, 690, 733, 734, 739, 754, 755, 767, 522, 883, 884, 885, 886, 887, 888, 889, 890, 891]
  LINE_WORKS_COMPANIES = [6, 623, 703, 770]

  ##############################
  # general
  ##############################

  def for_testing?
    self.id == 6 # company id of ディライテッド株式会社
  end

  def admin_employees
    self.employees.where(admin: true)
  end

  def primary_email
    employees.where(admin: true).first.email
  end

  ##############################
  # appointment
  ##############################

  def find_appointment_by_code(code)
    if code == '251200' && self.for_testing?
      self.appointments.order(begin_at: :desc).take
    else
      # TODO: use or condition (Rails 5)
      appointment = nil
      appointment = self.appointments.not_expiry_onetime_code.find_by(code: code)
      appointment = self.appointments.not_expiry_irregular_code.find_by(code: code) unless appointment
      appointment
    end
  end

  ##############################
  # notification related
  ##############################

  def for_line_works?
    LINE_WORKS_COMPANIES.include?(self.id)
  end

  def setting_chat_active?
    setting_chats.any?(&:active)
  end

  def get_mention_in(setting_custom)
    setting_chat = setting_custom.get_setting_chat(self)
    if setting_chat && setting_chat.active
      setting_chat.mention_in
    else
      false
    end
  end

  def get_token(setting_custom)
    setting_chat = setting_custom.get_setting_chat(self)
    if setting_chat && setting_chat.active
      setting_chat.token
    else
      false
    end
  end

  def get_token_and_msg(setting_custom)
    setting_chat = setting_custom.get_setting_chat(self)
    if setting_chat && setting_chat.active
      token = setting_chat.token
      msg = I18n.locale.equal?(:ja) ? setting_chat.msg : setting_chat.msg_en
      authorized = setting_chat.authorized && !setting_chat.token.include?("https")
    else
      token = false
    end
    return token, msg, authorized
  end

  def get_setting_chat_data(setting_custom)
    setting_custom.get_setting_chat(self)
  end

  def get_setting_chat(chat_name)
    setting_chats.find_by(chat_id: Chat.find_by(name: chat_name).id)
  end

  def setting_chat_slack
    setting_chats.find_by(chat_id: Chat.find_by(name: 'Slack').id)
  end

  def todays_notification_count
    self.notifications.where("created_at >= ?", Time.zone.now.beginning_of_day).size
  end

  ##############################
  # plan related
  ##############################

  def upgraded_plan? # ビジネスから上位のプラン
    self.enterprise? || self.premium?
  end

  def can_add_admin?
    self.upgraded_plan? && self.admin_employees.count < 5 + self.setting_apps.count - 1
  end

  def downgrade_to_free
    self.update(plan_status: "free")
  end

  def upgrade_to_basic
    self.update(plan_status: "standard")
  end

  def upgrade_to_business
    self.update(plan_status: "enterprise")
  end

  ##############################
  # payment related
  ##############################

  #####################
  # Pay.jp
  #####################
  #社員数　　料金
  #------------------------------------
  #  〜10　　　無料
  #11-50　　　JPY5000
  #51-100　　 JPY10000
  #101-150　　JPY15000
  #以降、50人ごとに＋JPY5000
  #端末台数　料金
  #------------------------------------
  #1　　　　無料（上記料金に含む）
  #2　　　　+JPY10000
  #3　　　　+JPY20000
  #以降、１台追加ごとに＋JPY10000

  # TODO: trial_expired_atカラム消す

  def payjp_registered?
    if PAYJP_EXCEPTIONS.include?(self.id)
      return true
    else
      return true if Payjp::Customer.retrieve(uid)
    end
  rescue => e
    false
  end

  def should_be_charged?
    payjp_registered? && measured_price?
  end

  def self.create_card_token(number, cvc, exp_month, exp_year)
    card = Payjp::Token.create(
        :card => {
          :number => number,
          :cvc => cvc,
          :exp_month => exp_month,
          :exp_year => exp_year
        }
      )
    return card
  end

  def create_customer_and_card(email, card_id)
    customer = Payjp::Customer.create(
      'id' => self.uid,
      'email' => email,
      'card' => card_id,
      'metadata[company_name]' => self.name
    )
    return customer
  end

  def update_card(number, cvc, exp_month, exp_year)
    status = false
    card = Company.create_card_token(number, cvc, exp_month, exp_year)
    if card.present?
      customer = Payjp::Customer.retrieve(self.uid)
      new_card = customer.cards.create(
        card: card.id
      )
      customer.default_card = new_card.id
      status_card = customer.save
      if status_card
        status = true
      end
    end

    return status
  end

  # 社員数課金情報
  def current_employee_subscription
    if ec_sub_id
      if current_employee_sub = Payjp::Subscription.retrieve(ec_sub_id)
        current_employee_sub
      else
        false
      end
    end
  end

  # タブレット台数課金情報
  def current_tablet_subscription
    if tc_sub_id
      if current_tablet_sub = Payjp::Subscription.retrieve(tc_sub_id)
        current_tablet_sub
      else
        false
      end
    end
  end

  def current_card
    if PAYJP_EXCEPTIONS.include?(self.id)
      true
    else
      customer =  Payjp::Customer.retrieve(uid)
      # card_idの情報を持っていないので、listからidを取得する
      card = customer.cards.all(limit: 1)
      if card['data'].present?
        card = customer.cards.retrieve(card['data'][0]['id'])
      else
        false
      end
    end
  rescue => e
    false
  end

  # csvで追加しようとしている人数を引数に取り、現在のプランの上限を越えているかを判定
  def ec_sub_should_be_updated?(value_counts)
    employee_count = self.employees.count
    plan_limit = self.max_employee_count - employee_count # プランの最大社員数と現在の社員数の差
    plan_changed = value_counts > plan_limit
    plan_changed
  end

  # 現在のプランでの最大社員数
  def max_employee_count
    employee_count = self.employees.count
    employee_count <= 10 ? 10 : (employee_count-1)/50*50+50
  end

  def expired_week_ago
    self.trial_expired_at - 1.week
  end

  def trial_expired?
    self.trial_expired_at >= Time.current
  end

  def employees_count_range(ec_plan_id=nil)
    employee_counts = ec_plan_id ? ec_plan_id.delete('^0-9').to_i : self.employees.count
    if employee_counts <= 10
      "0 ~ 10"
    else
      min_count = (employee_counts-1)/50*50+1 # 現在のプランでの最小社員数
      max_count = (employee_counts-1)/50*50+50 # 現在のプランでの最大社員数
      "#{min_count} ~ #{max_count}"
    end
  end

  def ec_plan_info(plan_id=nil)
    plan = plan_id || self.ec_plan_id
    if plan
      Payjp::Plan.retrieve(plan)
    else
      nil
    end
  end

  def tc_plan_info(plan_id=nil)
    plan = plan_id || self.tc_plan_id
    if plan
      Payjp::Plan.retrieve(plan)
    else
      nil
    end
  end

  def total_amount()
    current_tablet_plan = company.tc_plan_info
    tablet_fee = current_tablet_plan ? current_tablet_plan[:amount] : 0

    current_employee_plan = company.ec_plan_info
    employee_fee = current_employee_plan ? current_employee_plan[:amount] : 0
    tablet_fee + employee_fee
  end

  def reset_enterprise_features
    self.setting_apps.map { |setting_app| setting_app.update(admission: false) }
    self.setting_customs.map { |setting_custom| setting_custom.update(admission: false) }
  end

  private

  # 無料期間終了日時セット
  def set_expired_at
    self.trial_expired_at = Time.current.since(31.days)
  end
end
