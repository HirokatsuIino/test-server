# == Schema Information
#
# Table name: employees
#
#  id                      :integer          not null, primary key
#  email                   :string(255)      default(""), not null
#  encrypted_password      :string(255)      default(""), not null
#  reset_password_token    :string(255)
#  reset_password_sent_at  :datetime
#  reset_password_allow    :boolean
#  remember_created_at     :datetime
#  sign_in_count           :integer          default(0), not null
#  current_sign_in_at      :datetime
#  last_sign_in_at         :datetime
#  current_sign_in_ip      :string(255)
#  last_sign_in_ip         :string(255)
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  uid                     :string(255)      not null
#  name                    :string(255)
#  name_reading            :string(255)
#  name_reading_search     :string(255)
#  phone_no                :string(255)
#  icon_uri                :string(255)
#  company_id              :integer
#  admin                   :boolean          default(FALSE)
#  admin_authority_token   :string(255)
#  admin_authority_sent_at :datetime
#  admin_authorized_at     :datetime
#  department              :string(255)
#  slack                   :string(255)
#  slack_user_id           :string(255)
#  provider                :string(255)      default("email"), not null
#  confirmation_token      :string(255)
#  confirmed_at            :datetime
#  confirmation_sent_at    :datetime
#  tokens                  :text(65535)
#  refresh_tokens          :text(65535)
#  unconfirmed_email       :string(255)
#  active                  :boolean          default(FALSE), not null
#  name_reading_en         :string(255)
#  first_name              :string(255)
#  last_name               :string(255)
#  cw_id                   :string(255)
#  cw_account_id           :integer
#  slack_sub               :string(255)
#  slack_user_id_sub       :string(255)
#  cw_id_sub               :string(255)
#  cw_account_id_sub       :integer
#  uqid                    :string(255)      not null
#  one_team                :text(65535)
#  one_team_sub            :text(65535)
#  facebook_workplace      :text(65535)
#  facebook_workplace_sub  :text(65535)
#  dingtalk                :text(65535)
#  dingtalk_sub            :text(65535)
#  line_works              :text(65535)
#  line_works_sub          :text(65535)
#  timeline                :boolean          default(TRUE)
#  workchat                :boolean
#  ms_teams                :text(65535)
#  ms_teams_sub            :text(65535)
#  fcm_id                  :text(65535)
#

require 'csv'
require 'open-uri'
require 'nkf'

class Employee < ActiveRecord::Base
  # Include default devise modules.
  devise :database_authenticatable, :registerable,
          :recoverable, :rememberable, :trackable, :validatable,
          :confirmable  #:omniauthable
  include DeviseTokenAuth::Concerns::User
  include Uid
  mount_uploader :icon_uri, ImageUploader
  belongs_to :company
  has_many :sent_appointments, class_name: 'Appointment'
  has_many :visitors
  has_many :appointments_hosts
  has_many :appointments, :through => :appointments_hosts, dependent: :destroy
  has_many :mention_ins, class_name: 'EmployeeMention'
  has_many :chats, through: :mention_ins
  has_many :employee_notifications
  has_many :contacts
  has_many :notifications, through: :employee_notifications, dependent: :destroy
  has_one :employee_google, dependent: :destroy
  has_one :employee_microsoft, dependent: :destroy

  serialize :refresh_tokens, Hash

  before_save :remove_slack_mention!
  before_save :full_name_reading_en

  unless Rails.env.test?
    after_create :delete_emp_list_cache
  end
  after_save :update_name_reading_search

  MAX_FREE_PLAN = 10
  MAX_PAY_PLAN = 100

  scope :slack_unregistered, -> {
    where("slack IS NULL")
  }
  scope :slack_registered, -> {
    where("slack IS NOT NULL")
  }

  # logic for searching employees
  scope :notification_available, -> {
    where('slack IS NOT NULL OR cw_id IS NOT NULL OR cw_account_id IS NOT NULL OR one_team IS NOT NULL OR facebook_workplace IS NOT NULL OR line_works IS NOT NULL')
  }

  scope :notification_unavailable, -> {
    where('(slack IS NULL AND cw_id IS NULL AND cw_account_id IS NULL AND one_team IS NULL AND facebook_workplace IS NULL AND line_works IS NULL) OR (name_reading IS NULL OR name_reading_en IS NULL)')
  }

  scope :search_by_last_name, -> (name, exact_match) {
    exact_match.to_i == 1 ? where(last_name: name) : where('last_name like ?', "#{name}%")
  }

  scope :search_by_first_name, -> (name, exact_match) {
    exact_match.to_i == 1 ? where(first_name: name) : where('first_name like ?', "#{name}%")
  }

  scope :search_by_name, -> (name) {
    where('name like ?', "#{name}%")
  }

  scope :search_by_name_reading_search, -> (name, exact_match) {
    exact_match.to_i == 1 ? where(name_reading_search: name) : where('name_reading_search like ?', "#{name}%")
  }

  validates :email,
    presence: true

  before_validation :generate_uqid, on: :create
  validates :uqid,
    presence: true,
    uniqueness: { case_sensitive: false }

  def generate_refresh_token(client_id)
    token = SecureRandom.urlsafe_base64(nil, false)
    self.update(refresh_tokens: nil) unless self.refresh_tokens.is_a?(Hash)
    self.refresh_tokens[client_id] = token
    self.save!
    token
  end

  def get_admin_domain
    self.email =~ /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i
    $2
  end

  def update_slack_user_id(token, slack=nil)
    return true if Rails.env.test?
    if token.present? && !token.include?('https')
      result = SlackApi.get_user_id(token, slack || self.slack)
      return false unless result[:ok]
      self.update(slack_user_id: result[:slack_user_id]) if result[:ok]
    end
    return true
  end

  def update_slack_user_id_sub(token, slack_sub=nil)
    return true if Rails.env.test?
    if token.present? && !token.include?('https')
      result = SlackApi.get_user_id(token, slack_sub || self.slack_sub)
      result = SlackApi.get_group_id(token, slack_sub || self.slack_sub) unless result[:ok]
      return false unless result[:ok]
      self.update(slack_user_id_sub: result[:slack_user_id]) if result[:ok]
    end
    return true
  end

  def convert_name_reading
    return unless name_reading.present?
    name_reading.tr(SpecificJapanese::HASH.keys.join, SpecificJapanese::HASH.values.join)
  end

  def update_name_reading_search
    self.update_column(:name_reading_search, convert_name_reading) if name_reading_changed?
  end

  #override
  def token_validation_custom_response
    company = self.company.as_json(except: [:created_at, :updated_at])
    company.merge!(tablet_count: self.company.setting_apps.count) if self.company && self.company.setting_apps.present?
    self.as_json(except: [
      :tokens, :created_at, :updated_at
    ]).merge(company: company)
  end

  def should_get_slack_user_id?(params)
    self.slack != params[:slack]
  end

  def should_get_slack_user_id_sub?(params)
    self.company.upgraded_plan? && self.slack_sub != params[:slack_sub]
  end

  def self.to_csv(company)
    csv_data = CSV.generate do |csv|
      csv << csv_column_names(company)
      all.each do |employee|
        csv << employee.csv_column_values(company)
      end
    end
    csv_data.encode!("utf-16")
  end

  def self.csv_column_names(company)
    if company.for_line_works?
      ['名前', 'メールアドレス', '名前(カナ)', 'Firstname', 'Lastname', '部署', 'Slack ID', 'Slackのアシスタント用通知アカウント', 'Slackの通知先channel名', 'Chatwork ID', 'ChatWorkのアシスタント用ID', 'Chatwork アカウントID', 'ChatWorkのアシスタント用アカウントID', 'ChatWorkの通知先グループチャットURL', 'Oneteam ユーザーID', 'Oneteamのアシスタント用ユーザーID', 'Oneteam Webhook URL', 'Facebook Workplace ユーザーID', 'Facebook Workplace アシスタント用ユーザーID', 'Facebook Workplace グループID', 'LINE WORKS ユーザーID', 'LINE WORKS アシスタント用ユーザーID']
    elsif !company.for_line_works? && company.upgraded_plan?
      ['名前', 'メールアドレス', '名前(カナ)', 'Firstname', 'Lastname', '部署', 'Slack ID', 'Slackのアシスタント用通知アカウント', 'Slackの通知先channel名', 'Chatwork ID', 'ChatWorkのアシスタント用ID', 'Chatwork アカウントID', 'ChatWorkのアシスタント用アカウントID', 'ChatWorkの通知先グループチャットURL', 'Oneteam ユーザーID', 'Oneteamのアシスタント用ユーザーID', 'Oneteam Webhook URL', 'Facebook Workplace ユーザーID', 'Facebook Workplace アシスタント用ユーザーID', 'Facebook Workplace グループID']
    else
      ['名前', 'メールアドレス', '名前(カナ)', 'Firstname', 'Lastname', '部署', 'Slack ID', 'Chatwork ID', 'Chatwork アカウントID', 'Oneteam ユーザーID', 'Facebook Workplace ユーザーID']
    end
  end

  def csv_column_values(company)
    if company.for_line_works?
      [name, email, name_reading, first_name, last_name, department, slack, slack_sub, mention_ins.find_by(chat_id: 1).try(:mention_in), cw_id, cw_id_sub, cw_account_id, cw_account_id_sub, mention_ins.find_by(chat_id: 2).try(:mention_in), one_team, one_team_sub, mention_ins.find_by(chat_id: 3).try(:mention_in), facebook_workplace, facebook_workplace_sub, mention_ins.find_by(chat_id: 4).try(:mention_in), line_works, line_works_sub]
    elsif !company.for_line_works? && company.upgraded_plan?
      [name, email, name_reading, first_name, last_name, department, slack, slack_sub, mention_ins.find_by(chat_id: 1).try(:mention_in), cw_id, cw_id_sub, cw_account_id, cw_account_id_sub, mention_ins.find_by(chat_id: 2).try(:mention_in), one_team, one_team_sub, mention_ins.find_by(chat_id: 3).try(:mention_in), facebook_workplace, facebook_workplace_sub, mention_ins.find_by(chat_id: 4).try(:mention_in)]
    else
      [name, email, name_reading, first_name, last_name, department, slack, cw_id, cw_account_id, one_team, facebook_workplace]
    end
  end

  def has_upcoming_appointment?
    self.appointments.where(':now < begin_at', now: Time.zone.now).exists?
  end

  def destroyable?
    !self.has_upcoming_appointment?
  end


  def self.validate_csv(csv_file, admin_employee)
    company = admin_employee.company
    value_counts = 1 # カラム名の行は抜く
    emails = [] # CSV内重複チェック用
    instances = [] # employees保存用インスタンス
    instance_mentions = [] # employee_mentions保存用インスタンス

    csv = open_csv(csv_file.path, false)

    if csv.present?
      csv.each do |row|
        value_counts +=1
        row = rename_hash(row, company) if row['Email'] || row['メールアドレス']
        mentions = self.create_mentions_arr(row) if company.upgraded_plan?
        row = converse_char(row)
        check_instance(row, company)
        if @employee.invalid?
          error_msg = ''
          @employee.errors.full_messages.map { |e| error_msg = e }
          return  {msg: I18n.t(".controllers.applications.csv_error", error_line: value_counts) + error_msg}
        end
        if contains_email?(emails, @employee.email)
          return  {msg: I18n.t(".controllers.applications.duplicate_mail", error_line: value_counts)}
        end
        emails << @employee.email
        instances << @employee
        instance_mentions << mentions if company.upgraded_plan?
      end

      if company.ec_sub_should_be_updated?(value_counts) && !company.payjp_registered?
        # アップグレードするべきなのにカード登録していない
        return {msg: I18n.t(".controllers.applications.need_upgrade_plan")}
      elsif company.ec_sub_should_be_updated?(value_counts) && company.should_be_charged?
        save_instances(instances, instance_mentions, company)
        admin_employee.delete_emp_list_cache
        return nil
      else
        save_instances(instances, instance_mentions, company)
        admin_employee.delete_emp_list_cache
        return nil
      end

    else
      return {
        msg: I18n.t(".models.employee.invalid_csv_file")
      }
    end

  end

  def self.overrided_csv_info(csv_file, admin_employee)
    value_counts = 1
    company = admin_employee.company
    current_employees = admin_employee.company.employees
    current_employee_count = current_employees.size
    new_employee_count = updated_employee_count = unrelated_employee_count = 0
    current_employee_emails = current_employees.pluck(:email)

    csv = open_csv(csv_file.path, false)

    if csv.present?
      csv.each do |row|
        value_counts +=1
        email = row['メールアドレス'] ? row['メールアドレス'] : row['Email']
        if current_employee_emails.include?(email)
          employee = current_employees.find_by(email: email)
          row = rename_hash(row, company) if row['Email'] || row['メールアドレス']
          if will_be_updated?(row, employee, company)
            updated_employee_count += 1
            current_employee_emails.delete(employee.email)
          else
            unrelated_employee_count += 1
            current_employee_emails.delete(employee.email)
          end
        else
          new_employee_count += 1
          row = rename_hash(row, company) if row['Email'] || row['メールアドレス']
          check_instance(row, company)
          if @employee.invalid?
            error_msg = ''
            @employee.errors.full_messages.map { |e| error_msg = e }
            return  {
              msg: I18n.t(".controllers.applications.csv_error", error_line: value_counts) + error_msg
            }
          end
        end
      end

      deleted_employee_count = current_employee_count - (updated_employee_count + unrelated_employee_count)
      total_employee_count = (current_employee_count - deleted_employee_count) + new_employee_count

      if deleted_employee_count > 0
        undestoryable_employees = []
        current_employee_emails.each do |email|
          employee = Employee.find_by(email: email)
          undestoryable_employees.append(employee) unless employee.destroyable?
        end
      end

      # アップグレードするべきなのにカード登録していない
      if company.ec_sub_should_be_updated?(total_employee_count) && !company.payjp_registered?
        return {
          msg: I18n.t(".controllers.applications.need_upgrade_plan")
        }
      else
        if undestoryable_employees.present?
          return {
            msg: I18n.t(".models.employee.undestroyable_employees", number: deleted_employee_count, number_undestroyable: undestoryable_employees.size)
          }
        else
          return {
            new_employee_count: new_employee_count,
            updated_employee_count: updated_employee_count,
            deleted_employee_count: deleted_employee_count,
            file_url: admin_employee.company.csv_file.url,
            msg: nil
          }
        end
      end

    else

      return {
        msg: I18n.t(".models.employee.invalid_csv_file")
      }
    end

  end

  def self.override_csv(csv_file, admin_employee)
    related_employee_ids = [admin_employee.id]
    current_employees = admin_employee.company.employees
    company = admin_employee.company

    csv = open_csv(csv_file, true)

    if csv.present?
      csv.each do |row|
        row = rename_hash(row, company) if row['Email'] || row['メールアドレス']
        row = converse_char(row)
        request_params = row.to_hash.slice(*request_attributes(company))
        employee = current_employees.find_or_initialize_by(email: row['email'])

        if employee.new_record? # 新規登録
          password = Devise.friendly_token[0,10]
          employee.password = password
          employee.company_id = admin_employee.company_id
          employee.name = request_params['name']
          employee.name_reading = request_params['name_reading']
          employee.first_name = request_params['first_name']
          employee.last_name = request_params['last_name']
          employee.department = request_params['department']
          employee.slack = request_params['slack']
          employee.cw_id = request_params['cw_id']
          employee.cw_account_id = request_params['cw_account_id']
          employee.one_team = request_params['one_team']
          employee.facebook_workplace = request_params['facebook_workplace']
          employee.line_works = request_params['line_works'] if company.for_line_works?

          @redirect_url ||= DeviseTokenAuth.default_confirm_success_url
          # override email confirmation, must be sent manually from ctrl
          Employee.set_callback("create", :after, :send_on_create_confirmation_instructions)
          Employee.skip_callback("create", :after, :send_on_create_confirmation_instructions)
          employee.save!

          yield employee if block_given?

          unless employee.confirmed?
            # user will require email authentication
            path = '/api/auth/confirmation?'
            confirmation_root_path = Constants::API_ROOT + path
            custom_confirmation_url = confirmation_root_path + 'confirmation_token=' + employee.confirmation_token
            employee.delay.send_confirmation_instructions(
              redirect_url: @redirect_url,
              temp_password: password,
              type: "general",
              employee_email: employee.email,
              employee_name: employee.name,
              custom_confirmation_url: custom_confirmation_url.html_safe,
            )
          else
            # email auth has been bypassed, authenticate user
            @client_id = SecureRandom.urlsafe_base64(nil, false)
            @token     = SecureRandom.urlsafe_base64(nil, false)

            employee.tokens[@client_id] = {
              token: BCrypt::Password.create(@token),
              expiry: (Time.now + DeviseTokenAuth.token_lifespan).to_i
            }

            employee.save!
          end
        else # 更新
          employee.update_attributes!(request_params)
        end

        if company.upgraded_plan?
          employee.update_attributes!(
            slack_sub: row["slack_sub"],
            cw_id_sub: row["cw_id_sub"],
            cw_account_id_sub: row["cw_account_id_sub"],
            one_team_sub: row["one_team_sub"],
            facebook_workplace_sub: remove_whitespace(row["facebook_workplace_sub"])
          )
          employee.update_attributes!(line_works_sub: row["line_works_sub"]) if company.for_line_works?
          employee.update_mentions(self.create_mentions_arr(row))
          employee.update_attributes!(line_works_sub: row["line_works_sub"]) if company.for_line_works?
        end

        related_employee_ids.push(employee.id)

      end
      # 削除
      delete_employees = current_employees.where.not(id: related_employee_ids)
      delete_employees.map do |employee|
        employee.mention_ins.destroy_all
        employee.destroy!
      end

      admin_employee.delete_emp_list_cache
    else

      return {
        msg: I18n.t(".models.employee.invalid_csv_file")
      }
    end

  end

  def self.request_attributes(company)
    if company.for_line_works?
      ['name', 'email', 'name_reading', 'first_name', 'last_name', 'slack', 'department', 'cw_id', 'cw_account_id', 'one_team', 'facebook_workplace', 'line_works']
    else
      ['name', 'email', 'name_reading', 'first_name', 'last_name', 'slack', 'department', 'cw_id', 'cw_account_id', 'one_team', 'facebook_workplace']
    end
  end

  # チャットごとに通知先をemployee_mentionsに保存
=begin
  {
    "mentions": [
      {
        "chat": {"id": 1},
        "mention_in": "develop"
      },
      {
        "chat": {"id": 2},
        "mention_in": "something"
      }
    ]
  }
=end
  def update_mentions(mentions)
    if mentions.present?
      mentions.each do |mention|
        em = self.mention_ins.find_by(employee_id: self.id, chat_id: mention[:chat][:id])
        if em.present?
          # 既に指定されたチャネルの通知先が設定されているので、チャネル名のみ更新
          em.update(mention_in: mention[:mention_in])
        else
          # 指定されたチャネルの通知先が設定されていないので、レコードを作る
          EmployeeMention.create(
            chat_id: mention[:chat][:id],
            employee_id: self.id,
            mention_in: mention[:mention_in]
          )
        end
      end
    end
  end

  def self.rename_hash(row, company)
    new_row = {}
    new_row["email"] = row["メールアドレス"] ? row["メールアドレス"] : row["Email"]
    new_row["name"] = row["名前"] ? row["名前"] : row["Name"]
    new_row["name_reading"] = row["名前(カナ)"] ? row["名前(カナ)"] : row["NameReading"]
    new_row["first_name"] = row["Firstname"]
    new_row["last_name"] = row["Lastname"]
    new_row["department"] = row["部署"] ? row["部署"] : row["Department"]
    new_row["slack"] = row["Slack ID"] ? row["Slack ID"] : row["SlackId"]
    new_row["cw_id"] = row["Chatwork ID"] ? row["Chatwork ID"] : row["ChatWorkId"]
    new_row["cw_account_id"] = row["Chatwork アカウントID"] ? row["Chatwork アカウントID"] : row["ChatWorkAccountId"]
    new_row["one_team"] = row["Oneteam ユーザーID"]
    new_row["facebook_workplace"] = row["Facebook Workplace ユーザーID"]
    new_row["line_works"] = row["LINE WORKS ユーザーID"] if company.for_line_works?
    if company.upgraded_plan?
      new_row["slack_sub"] = row["Slackのアシスタント用通知アカウント"] ? row["Slackのアシスタント用通知アカウント"] : row["SlackAssistantId"]
      new_row["cw_id_sub"] = row["ChatWorkのアシスタント用ID"] ? row["ChatWorkのアシスタント用ID"] : row["ChatWorkAssistantId"]
      new_row["cw_account_id_sub"] = row["ChatWorkのアシスタント用アカウントID"] ? row["ChatWorkのアシスタント用アカウントID"] : row["ChatWorkAssistantAccountId"]
      new_row["one_team_sub"] = row["Oneteamのアシスタント用ユーザーID"]
      new_row["facebook_workplace_sub"] = row["Facebook Workplace アシスタント用ユーザーID"]
      new_row["line_works_sub"] = row["LINE WORKS アシスタント用ユーザーID"] if company.for_line_works?
      new_row["SlackMentionIn"] = row["Slackの通知先channel名"] ? row["Slackの通知先channel名"] : row["SlackMentionIn"]
      new_row["ChatworkMentionIn"] = row["ChatWorkの通知先グループチャットURL"] ? row["ChatWorkの通知先グループチャットURL"] : row["ChatworkMentionIn"]
      new_row["OneteamMentionIn"] = row["Oneteam Webhook URL"]
      new_row["WorkplaceMentionIn"] = row["Facebook Workplace グループID"]
    end
    new_row
  end

  # delete cache of employees list
  def delete_emp_list_cache
    return if Rails.env.test?
    if company = self.company
      employees_reg_key = "*#{company.id}/employees#index/*"
      visitors_reg_key = "*#{company.id}/visitors#employees/*"
      Rails.cache.delete_matched(employees_reg_key)
      Rails.cache.delete_matched(visitors_reg_key)
    end
  end

  private

  def generate_uqid
    self.uqid ||= SecureRandom.uuid
  end

  def remove_slack_mention!
    if self.slack
      if self.slack.include?("@")
        self.slack.delete!("@")
      end
    end
  end

  def full_name_reading_en
    if first_name && last_name
      self.name_reading_en = "#{first_name} #{last_name}"
    end
  end

  def self.converse_char(row)
    # row["name"] = NKF.nkf('-W -s', row["name"])
    row["name"] = NKF.nkf('-w', row["name"])
    return row
  end

  def self.open_csv(csv_path, remote)
    begin
      file = open(csv_path, "rb:bom|Shift_JIS:UTF-8", undef: :replace) unless remote
      file = File.open(open(csv_path), "rb:bom|Shift_JIS:UTF-8", undef: :replace) if remote
      csv = CSV.new(file, headers: true)
    rescue Encoding::InvalidByteSequenceError => e
      p "Encoding::InvalidByteSequenceError"
      begin
        file = open(csv_path, "rb:bom|UTF-8", undef: :replace) unless remote
        file = File.open(open(csv_path), "rb:bom|UTF-8", undef: :replace) if remote
        csv = CSV.new(file, headers: true)
      rescue Encoding::InvalidByteSequenceError => e
        p "Encoding::InvalidByteSequenceError"
        csv = nil
      end
    end
    csv
  end

  # csvから作成したインスタンスを全て保存しユーザーを登録する
  def self.save_instances(instances, instance_mentions, company)
    Employee.transaction do
      instances.each.with_index do |employee, idx|
        password = Devise.friendly_token[0,10]
        employee.password = password
        employee.company_id = company.id
        @redirect_url ||= DeviseTokenAuth.default_confirm_success_url
        # override email confirmation, must be sent manually from ctrl
        Employee.set_callback("create", :after, :send_on_create_confirmation_instructions)
        Employee.skip_callback("create", :after, :send_on_create_confirmation_instructions)
        employee.save!
        yield employee if block_given?

        unless employee.confirmed?
          # user will require email authentication
          path = '/api/auth/confirmation?'
          confirmation_root_path = Constants::API_ROOT + path
          custom_confirmation_url = confirmation_root_path + 'confirmation_token=' + employee.confirmation_token
          employee.delay.send_confirmation_instructions(
            redirect_url: @redirect_url,
            temp_password: password,
            type: "general",
            employee_email: employee.email,
            employee_name: employee.name,
            custom_confirmation_url: custom_confirmation_url.html_safe,
          )
          employee.update_mentions(instance_mentions[idx]) if company.upgraded_plan?
        else
          # email auth has been bypassed, authenticate user
          @client_id = SecureRandom.urlsafe_base64(nil, false)
          @token     = SecureRandom.urlsafe_base64(nil, false)

          employee.tokens[@client_id] = {
            token: BCrypt::Password.create(@token),
            expiry: (Time.now + DeviseTokenAuth.token_lifespan).to_i
          }

          employee.save!
          employee.update_mentions(instance_mentions[idx]) if company.upgraded_plan?
        end
      end
    end
  end

  def self.check_instance(row, company)
    request_params = row.to_hash.slice(*request_attributes(company))
    request_params['facebook_workplace'] = remove_whitespace(request_params['facebook_workplace'])
    @employee = Employee.new(request_params)
    if company.upgraded_plan?
      @employee.slack_sub = row['slack_sub']
      @employee.cw_id_sub = row['cw_id_sub']
      @employee.cw_account_id_sub = row['cw_account_id_sub']
      @employee.one_team_sub = row['one_team_sub']
      @employee.facebook_workplace_sub = remove_whitespace(row['facebook_workplace_sub'])
    end
    @employee.password = 'password'
    @employee.provider = 'email'
  end

  def self.create_mentions_arr(row)
    [
      {chat: {id: 1}, mention_in: row["SlackMentionIn"]},
      {chat: {id: 2}, mention_in: row["ChatworkMentionIn"]},
      {chat: {id: 3}, mention_in: row["OneteamMentionIn"]},
      {chat: {id: 4}, mention_in: row["WorkplaceMentionIn"]}
    ]
  end

  def self.will_be_updated?(row, employee, company)
    employee_changed = false
    request_params = row.to_hash.slice(*request_attributes(company))
    self.request_attributes(company).each do |attribute|
      if attribute != 'cw_account_id'
        employee_changed = true if employee[attribute] != request_params[attribute]
      elsif attribute == 'cw_account_id' && request_params[attribute]
        employee_changed = true if employee[attribute] != request_params[attribute].to_i
      end
    end

    if company.upgraded_plan?
      enterprise_attributes = ['slack_sub', 'cw_id_sub', 'cw_account_id_sub', 'one_team_sub', 'facebook_workplace_sub']
      enterprise_attributes.each do |attribute|
        if attribute != 'cw_account_id_sub'
        employee_changed = true if employee[attribute] != row[attribute]
        elsif attribute == 'cw_account_id_sub' && row[attribute]
          employee_changed = true if employee[attribute] != row[attribute].to_i
        end
      end
      mention_ins = employee.mention_ins
      mention_in_changed = false
      mention_in_changed = true if mention_ins.find_by(chat_id: 1).try(:mention_in) != row['SlackMentionIn']
      mention_in_changed = true if mention_ins.find_by(chat_id: 2).try(:mention_in) != row['ChatworkMentionIn']
      mention_in_changed = true if mention_ins.find_by(chat_id: 3).try(:mention_in) != row['OneteamMentionIn']
      mention_in_changed = true if mention_ins.find_by(chat_id: 4).try(:mention_in) != row['WorkplaceMentionIn']
      employee_changed || mention_in_changed
    else
      employee_changed
    end
  end

  def self.contains_email?(emails, own)
    emails.include?(own)
  end

  def self.remove_whitespace(string)
    string.gsub(/\s+/, "") unless string.nil?
  end

end
