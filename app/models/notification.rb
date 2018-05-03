# == Schema Information
#
# Table name: notifications
#
#  id            :integer          not null, primary key
#  uid           :string(255)
#  chat_id       :integer
#  company_id    :integer
#  notifier_type :integer
#  printer_flag  :boolean          default(FALSE), not null
#  number        :integer          default(0), not null
#  status        :integer          default(0), not null
#  msg           :string(255)
#  mention_in    :string(255)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

require "chatwork"
# require 'net/http'

class Notification < ActiveRecord::Base
  include Uid
  has_many :employee_notifications
  has_many :employees, through: :employee_notifications
  belongs_to :company

  enum status: ['NONE', 'OK', 'HELP', 'OK_AFTER_HELP']
  NOTIFY_RETRY = 3 # 何回目で再通知先に通知するか
  NOTIFY_LIMIT = 5 # 何回目で通知をやめるか
  NOTIFY_INTERVAL = 55.seconds

  SLACK_COMMANDS = %w(channel group here everyone)

  # global var for job notification
  @@recurrent_info = {is_slack: false, active: false}
  @@redis = Redis::Namespace.new("notification_slack", redis: Redis.current)

  #####################
  # Notifiers
  #####################
  # Notification by Line Works
  def self.notify_to_line_works(notify_params, setting_chat)
    if notify_params[:notifier_type] == :notify_with_code
      line_works_with_code(
        notify_params[:msg],
        notify_params[:mention_to],
        notify_params[:room],
        notify_params[:visitor_number],
        notify_params[:tablet_location],
        notify_params[:mention_in],
        setting_chat,
        notify_params
      )
    elsif notify_params[:notifier_type] == :notify_without_code
      line_works_without_code(
        notify_params[:msg],
        notify_params[:mention_to],
        notify_params[:mention_to_sub],
        notify_params[:company_name],
        notify_params[:name],
        notify_params[:number],
        notify_params[:mention_name],
        notify_params[:tablet_location],
        setting_chat,
        notify_params
      )
    elsif notify_params[:notifier_type] == :notify_by_custom
      line_works_custom(
        notify_params[:msg],
        notify_params[:mention_to],
        notify_params[:custom_text],
        notify_params[:visitor_name],
        notify_params[:visitor_company],
        notify_params[:visitor_number],
        notify_params[:tablet_location],
        setting_chat
      )
    end
  end

  def self.notify_to_facebook_workplace(notify_params, setting_chat)
    if notify_params[:notifier_type] == :notify_with_code
      facebook_workplace_with_code(
        notify_params[:msg],
        notify_params[:mention_to],
        notify_params[:room],
        notify_params[:visitor_number],
        notify_params[:tablet_location],
        notify_params[:mention_in],
        setting_chat
      )
    elsif notify_params[:notifier_type] == :notify_without_code
      facebook_workplace_without_code(
        notify_params[:msg],
        notify_params[:mention_to],
        notify_params[:mention_to_sub],
        notify_params[:company_name],
        notify_params[:name],
        notify_params[:number],
        notify_params[:mention_name],
        notify_params[:tablet_location],
        notify_params[:mention_in],
        setting_chat
      )
    elsif notify_params[:notifier_type] == :notify_by_custom
      facebook_workplace_custom(
        notify_params[:msg],
        notify_params[:mention_to],
        notify_params[:custom_text],
        notify_params[:visitor_name],
        notify_params[:visitor_company],
        notify_params[:visitor_number],
        notify_params[:tablet_location],
        notify_params[:mention_in],
        setting_chat
      )
    end
  rescue => e
    raise e
  end

  def self.notify_to_dingtalk(notify_params, setting_chat)
    if notify_params[:notifier_type] == :notify_with_code
      dingtalk_with_code(notify_params[:msg], notify_params[:mention_to], notify_params[:room], notify_params[:visitor_number], notify_params[:tablet_location],notify_params, setting_chat)
    elsif notify_params[:notifier_type] == :notify_without_code
      dingtalk_without_code(notify_params[:msg], notify_params[:mention_to], notify_params[:mention_to_sub], notify_params[:company_name], notify_params[:name], notify_params[:number], notify_params[:mention_name], notify_params[:tablet_location], setting_chat, notify_params)
    elsif notify_params[:notifier_type] == :notify_by_custom
      dingtalk_custom(notify_params[:msg], notify_params[:mention_to], notify_params[:custom_text], notify_params[:visitor_name], notify_params[:visitor_company], notify_params[:visitor_number], notify_params[:tablet_location], setting_chat, notify_params[:mention_in])
    end
  rescue => e
    raise e
  end

  def self.notify_to_ms_team(notify_params, setting_chat)
    if notify_params[:notifier_type] == :notify_with_code
      ms_team_with_code(notify_params[:msg], notify_params[:mention_to], notify_params[:room], notify_params[:visitor_number], notify_params[:tablet_location],notify_params, notify_params[:mention_in])
    elsif notify_params[:notifier_type] == :notify_without_code
      ms_team_without_code(notify_params[:msg], notify_params[:mention_to], notify_params[:mention_to_sub], notify_params[:company_name], notify_params[:name], notify_params[:number], notify_params[:mention_name], notify_params[:tablet_location], setting_chat, notify_params)
    elsif notify_params[:notifier_type] == :notify_by_custom
      ms_team_custom(notify_params[:msg], notify_params[:mention_to], notify_params[:custom_text], notify_params[:visitor_name], notify_params[:visitor_company], notify_params[:visitor_number], notify_params[:tablet_location], setting_chat, notify_params[:mention_in])
    end
  rescue => e
    raise e
  end

  # Notification by One Team
  def self.notify_to_one_team(**notify_params)
    status = false
    if notify_params[:notifier_type] == :notify_with_code
      one_team_with_code(notify_params[:msg], notify_params[:mention_to], notify_params[:room], notify_params[:visitor_number], notify_params[:tablet_location], notify_params[:token], notify_params[:mention_in])
    elsif notify_params[:notifier_type] == :notify_without_code
      one_team_without_code(notify_params[:msg], notify_params[:mention_to], notify_params[:mention_to_sub], notify_params[:company_name], notify_params[:name], notify_params[:number], notify_params[:mention_name], notify_params[:tablet_location], notify_params[:token], notify_params[:mention_in])
    elsif notify_params[:notifier_type] == :notify_by_custom
      one_team_custom(notify_params[:msg], notify_params[:mention_to], notify_params[:custom_text], notify_params[:visitor_name], notify_params[:visitor_company], notify_params[:visitor_number], notify_params[:tablet_location], notify_params[:token])
    end
  rescue => e
    raise e
    # logger.error(e)
    # status = error_with_locale(notify_params[:lang], '.models.notification.slack_failure')
  ensure
    status
  end
  # Notification by Slack
  def self.notify_to_slack(**notify_params)
    status = false
    slack_notifier_init(notify_params[:token], notify_params[:mention_in], notify_params[:authorized])
    if notify_params[:notifier_type] == :notify_with_code
      slack_with_code(notify_params[:msg], notify_params[:mention_to], notify_params[:room], notify_params[:visitor_number], notify_params[:tablet_location], notify_params[:token], notify_params[:authorized])
    elsif notify_params[:notifier_type] == :notify_without_code
      slack_without_code(notify_params[:msg], notify_params[:mention_to], notify_params[:mention_to_sub], notify_params[:company_name], notify_params[:name], notify_params[:number], notify_params[:mention_name], notify_params[:tablet_location], notify_params[:token], notify_params[:authorized], notify_params[:sub_group], notify_params[:mention_to_sub_name])
    elsif notify_params[:notifier_type] == :notify_by_custom
      slack_custom(notify_params[:msg], notify_params[:mention_to], notify_params[:custom_text], notify_params[:visitor_name], notify_params[:visitor_company], notify_params[:visitor_number], notify_params[:slack_group], notify_params[:slack_group_id], notify_params[:tablet_location], notify_params[:token], notify_params[:authorized])
    end
    @notifier = nil
  rescue => e
    logger.error(e)
    status = error_with_locale(notify_params[:lang], '.models.notification.slack_failure')
  ensure
    status
  end

  # Notification by Chatworkd
  def self.notify_to_cw(**notify_params)
    status = false
    cw_notifier_init(notify_params[:token])

    if notify_params[:notifier_type] == :notify_with_code
      cw_with_code(notify_params[:msg], notify_params[:mention_in], notify_params[:mention_to], notify_params[:room], notify_params[:visitor_number], notify_params[:tablet_location])
    elsif notify_params[:notifier_type] == :notify_without_code
      cw_without_code(notify_params[:msg], notify_params[:mention_in], notify_params[:mention_to], notify_params[:mention_to_sub], notify_params[:company_name], notify_params[:name], notify_params[:number], notify_params[:mention_name], notify_params[:tablet_location])
    elsif notify_params[:notifier_type] == :notify_by_custom
      cw_custom(notify_params[:msg], notify_params[:mention_in], notify_params[:mention_to], notify_params[:custom_text], notify_params[:visitor_name], notify_params[:visitor_company], notify_params[:visitor_number], notify_params[:tablet_location])
    end

  rescue => e
    logger.error(e)
    status = error_with_locale(notify_params[:lang], '.models.notification.cw_failure')
  ensure
    status
  end

  # Notification by Custom Button
  def self.notify_by_custom(company, setting_custom, visitor, tablet_location, lang)
    @@recurrent_info.merge!({ company_id: company.id })
    status = false
    # send mail
    if setting_custom.email_to.present?
      visitor_info = visitor.presence || {}
      NotificationMailer.notify_from_custom(setting_custom, setting_custom.email_to, visitor_info, Time.current.to_s).deliver_later
    end
    if setting_custom.active
      chats = [setting_custom.chat.id] # for logging notifications
      # 言語に応じてカラムを変更する
      setting_custom_text = I18n.locale.equal?(:ja) ? setting_custom.text : setting_custom.text_en
      notify_params = {
        notifier_type: __method__,
        custom_text: setting_custom_text,
        slack_group: setting_custom.slack_group,
        slack_group_id: setting_custom.slack_group_id,
        mention_to: setting_custom.custom_mentions.pluck(:mention_to).reject(&:blank?),
        tablet_location: tablet_location,
        lang: lang
      }
      mention_in = setting_custom.mention_in.present? ? setting_custom.mention_in : company.get_mention_in(setting_custom) unless setting_custom.chat.name == 'Oneteam' #|| setting_custom.chat.name == 'LINE WORKS'
      mention_in  = setting_custom.mention_in.present? ? setting_custom.mention_in : company.get_token(setting_custom) if setting_custom.chat.name == 'Oneteam' || setting_custom.chat.name == 'Microsoft Teams' # get token in setting chat if no mention in
      # mention_in  = setting_custom.mention_to.present? ? setting_custom.mention_to : setting_custom.custom_mentions.limit(5).map{|cm| cm.line_works_id}.uniq  if setting_custom.chat.name == 'LINE WORKS'
      notify_params.merge!(mention_in: mention_in)
      notify_params.merge!(
        visitor_name: visitor[:name],
        visitor_company: visitor[:company],
        visitor_number: visitor[:number]
      )  if visitor.present?
      # 言語に応じてカラムを変更する
      msg = I18n.locale.equal?(:ja) ? setting_custom.msg : setting_custom.msg_en
      token, sc_msg, authorized = company.get_token_and_msg(setting_custom)
      setting_chat = company.get_setting_chat_data(setting_custom)
      msg = sc_msg unless msg.present?
      if token
        notify_params.merge!(msg: msg)
        if setting_custom.chat.name == "Slack"
          notify_params.merge!(token: token, authorized: authorized)
          notify_params[:mention_to] = notify_params[:mention_to].last
          if setting_chat.is_using_slack_app? && !SLACK_COMMANDS.include?(notify_params[:mention_to])
            # TODO: case where setting_custom has multiple custom mentions
            cm = setting_custom.custom_mentions.last
            setting_custom.update_slack_user_id(token) if cm.mention_to && !cm.slack_user_id
            notify_params[:mention_to] = setting_custom.custom_mentions.last.slack_user_id
          end
          @@recurrent_info.merge!({is_slack: true, active: setting_chat.recurrent, count: company.todays_notification_count})
          notify_status = self.notify_to_slack(notify_params)
        elsif setting_custom.chat.name == "Chatwork"
          if setting_custom.custom_mentions.all?(&:cw_account_id)
            notify_params[:mention_to] = setting_custom.custom_mentions.pluck(:cw_account_id)
          else
            account_ids = []
            setting_custom.custom_mentions.each do |cm|
              if cm.cw_account_id
                account_ids.push(cm.cw_account_id)
              else
                account_id = setting_custom.get_account_id(cm.mention_to, notify_params[:mention_in])
                if account_id
                  cm.update(cw_account_id: account_id)
                  account_ids.push(account_id)
                end
              end
            end
            notify_params[:mention_to] = account_ids
          end
          notify_params.merge!(token: token)
          notify_status = self.notify_to_cw(notify_params)
          if notify_status.include?("message_id")
            notify_status = nil
          end
        elsif setting_custom.chat.name == "Oneteam"
          notify_params.merge!(token: mention_in, type: 'message')
          self.notify_to_one_team(notify_params)
        elsif setting_custom.chat.name == "LINE WORKS"
          notify_params.merge!(group_id: setting_chat.mention_in) # company id as in asei@'delighted'
          self.notify_to_line_works(notify_params, setting_chat)
        elsif setting_custom.chat.name == 'Facebook Workplace'
          self.notify_to_facebook_workplace(notify_params, setting_chat)
        elsif setting_custom.chat.name == 'DingTalk'
          self.notify_to_dingtalk(notify_params, setting_chat)
        elsif setting_custom.chat.name == 'Microsoft Teams'
          self.notify_to_ms_team(notify_params, setting_chat)
        end
      end
    end
  rescue => e
    logger.error(e)
    status = error_with_locale(lang, '.models.notification.failure')
  ensure
    if notify_status
      return notify_status, chats, @@recurrent_info
    else
      return status, chats, @@recurrent_info
    end
  end

  # Notification by Invidation Code
  def self.notify_with_code(appointment, visitor, tablet_location, lang, company = nil, setting_custom = nil)
    @@recurrent_info.merge!({ company_id: company.try(:id) })
    status = false
    notify_status = false
    hosts = appointment.hosts
    hosts.each do |host|
      if host.company.reception_mail_allowed?
        AppointmentMailer.visit_guest(host, appointment, tablet_location).deliver_later
      end
    end
    notify_params = {
      notifier_type: __method__,
      room: appointment.place,
      tablet_location: tablet_location,
      lang: lang
    }
    notify_params.merge!(visitor_number: visitor[:number]) if visitor.present?

    scs = hosts.first.company.setting_chats
    chats = []
    scs.each do |s|
      if s.active
        msg = I18n.locale.equal?(:ja) ? s.msg : s.msg_en # 言語に応じてカラムを変更する
        mention_ins = self.get_mention_ins(hosts, s) # 各社員の通知先チャネルを取得
        if s.chat.name == 'Slack'
          @@recurrent_info.merge!({is_slack: true, active: s.recurrent, count: company.todays_notification_count})
          chats.append(s.chat.id)
          notify_status = false
          mention_to = get_mention_to(hosts, s)
          mention_ins.each do |mention_in|
            status_flag = self.notify_to_slack(
              notify_params.merge(
                token: s.token,
                msg: msg,
                mention_to: mention_to,
                mention_in: mention_in,
                authorized: s.authorized && !s.token.include?("https")
              )
            )
            # TODO: 複数回エラーの場合の保持
            notify_status = status_flag if status_flag
          end
        elsif s.chat.name == 'Chatwork'
          chats.append(s.chat.id)
          # run get account id
          hosts.each do |employee|
            if (employee.cw_id && s.mention_in && s.token) && !employee.cw_account_id
              account_id = s.get_account_id(employee.cw_id)
              if account_id
                employee.update(cw_account_id: account_id)
              end
            end
          end
          notify_status = false
          mention_ins.each do |mention_in|
            status_flag = self.notify_to_cw(
              notify_params.merge(
                token: s.token,
                msg: msg,
                mention_to: hosts.pluck(:cw_account_id, :name, :cw_account_id_sub),
                mention_in: mention_in
              )
            )
            # TODO: 複数回エラーの場合の保持
            if status_flag.include?("message_id")
              status_flag = nil
            else
              notify_status = status_flag
            end
          end
        elsif s.chat.name == 'Oneteam'
          chats.append(s.chat.id)
          notify_status = false
          mention_ins.each do |mention_in|
            status_flag = self.notify_to_one_team(
              notify_params.merge(
                token: s.token,
                msg: msg,
                mention_to: hosts.pluck(:one_team, :name, :one_team_sub),
                mention_in: mention_in
              )
            )
            # TODO: 複数回エラーの場合の保持
            notify_status = status_flag if status_flag
          end
        elsif s.chat.name == 'LINE WORKS'
          notify_status = false
          mention_ins.each do |mention_in|
            status_flag = self.notify_to_line_works(
              notify_params.merge(
                token: s.token,
                msg: msg,
                mention_to: hosts.pluck(:line_works, :name, :line_works_sub),
                mention_in: mention_in,
                group_id: s.mention_in
              ), s
            )
            # TODO: 複数回エラーの場合の保持
            status_flag ? notify_status = status_flag : chats.append(s.chat.id)
          end
        elsif s.chat.name == 'Facebook Workplace'
          chats.append(s.chat.id)
          notify_status = false
          mention_ins.each do |mention_in|
            notify_params.merge!(
              token: s.token,
              msg: msg,
              mention_to: hosts.pluck(:facebook_workplace, :name, :facebook_workplace_sub),
              mention_in: mention_in
            )
            status_flag = self.notify_to_facebook_workplace(notify_params, s)
            notify_params = status_flag if status_flag
          end
        elsif s.chat.name == 'DingTalk'
          notify_status = false
          mention_ins.each do |mention_in|
            status_flag = self.notify_to_dingtalk(
              notify_params.merge(
                  token: s.token,
                  msg: msg,
                  mention_to: hosts.pluck(:dingtalk, :name, :dingtalk_sub),
                  mention_in: mention_in
                ), s
              )
            status_flag ? notify_params = status_flag : chats.append(s.chat.id)
          end
        elsif s.chat.name == 'Microsoft Teams'
          notify_status = false
          mention_ins.each_with_index do |mention_in, i|
            status_flag = self.notify_to_ms_team(
              notify_params.merge(
                  token: s.token,
                  msg: msg,
                  mention_to: hosts.pluck(:ms_teams, :name, :ms_teams_sub),
                  mention_in: mention_in,
                  image_url: hosts[i].icon_uri.url
                ), s
              )
            status_flag ? notify_params = status_flag : chats.append(s.chat.id)
          end
        end
      end
    end
    # AppointmentMailer.visit_guest(appointment.hosts.first, appointment).deliver
    # @notification.update(receiver_id: appointment.hosts.first.id)
  rescue => e
    logger.error(e)
    status = error_with_locale(lang, '.models.notification.failure')
  ensure
    if notify_status
      return notify_status, chats, @@recurrent_info
    else
      return status, chats, @@recurrent_info
    end
  end

  # Notification wihtout Invitation Code
  def self.notify_without_code(visitor_params, visitee_uqid, tablet_location, lang, setting_custom = nil, company = nil)
    @@recurrent_info.merge!({ company_id: company.try(:id) })
    status = false
    employee = Employee.find_by(uqid: visitee_uqid)

    if employee && employee.company.reception_mail_allowed?
      NotificationMailer.search_notification(employee, visitor_params, Time.current.to_s, tablet_location).deliver_later
    end

    notify_params = {
      notifier_type: __method__,
      name: visitor_params[:name],
      company_name: visitor_params[:company],
      number: visitor_params[:number],
      tablet_location: tablet_location,
      lang: lang
    }

    notify_status = nil
    scs = employee.company.setting_chats
    if setting_custom
      setting_chat = company.get_setting_chat_data(setting_custom)
    end
    chats = []
    scs.each do |s|
      if s.active
        msg = I18n.locale.equal?(:ja) ? s.msg : s.msg_en # 言語に応じてカラムを変更する
        mention_ins = self.get_mention_ins([employee], s) # 各社員の通知先チャネルを取得
        if s.chat.name == 'Slack'
          sub_group = false
          chats.append(s.chat.id)
          mention_to = employee.slack
          mention_to_sub = employee.slack_sub
          if s.authorized && !s.token.include?("https")
            employee.update_slack_user_id(s.token)
            mention_to = employee.slack_user_id if employee.slack_user_id.present?
            if mention_to_sub.present?
              sub_result = SlackApi.get_user_id(s.token, mention_to_sub)
              unless sub_result[:ok]
                sub_result = SlackApi.get_group_id(s.token, mention_to_sub)
                sub_group = true
              end
              mention_to_sub = sub_result[:slack_user_id]
            end
          end
          notify_params.merge!(
            token: s.token,
            msg: msg,
            mention_to: mention_to,
            mention_to_sub: mention_to_sub,
            mention_in: mention_ins[0],
            mention_name: employee.name,
            authorized: s.authorized && !s.token.include?("https"),
            sub_group: sub_group,
            mention_to_sub_name: employee.slack_sub
          )
          @@recurrent_info.merge!({is_slack: true, active: s.recurrent, count: company.todays_notification_count})
          notify_status = self.notify_to_slack(notify_params)
        elsif s.chat.name == 'Chatwork'
          chats.append(s.chat.id)
          #TODO? ロジック
          if !employee.cw_account_id
            account_id = s.get_account_id(employee.cw_id)
            if account_id
              employee.update(cw_account_id: account_id)
            end
          end
          # 言語に応じてカラムを変更する
          msg = I18n.locale.equal?(:ja) ? s.msg : s.msg_en
          # msg = s.msg # ??
          mention_ins = self.get_mention_ins([employee], s)

          notify_params.merge!(
            token: s.token,
            msg: msg,
            mention_to: employee.cw_account_id,
            mention_to_sub: employee.cw_account_id_sub,
            mention_in: mention_ins[0],
            mention_name: employee.name
          )
          notify_status = self.notify_to_cw(notify_params)
          notify_status = nil if notify_status.include?("message_id")
        elsif s.chat.name == 'Oneteam'
          chats.append(s.chat.id)
          notify_params.merge!(
            token: s.token,
            msg: msg,
            mention_to: employee.one_team,
            mention_to_sub: employee.one_team_sub,
            mention_in: mention_ins,
            mention_name: employee.name
          )
          notify_status = self.notify_to_one_team(notify_params)
        elsif s.chat.name == 'LINE WORKS'
          notify_params.merge!(
            token: s.token,
            msg: msg,
            mention_to: employee.line_works,
            mention_to_sub: employee.line_works_sub,
            mention_in: mention_ins,
            mention_name: employee.name,
            group_id: s.mention_in
          )
          notify_status = self.notify_to_line_works(notify_params,s)
          chats.append(s.chat.id) unless notify_status
        elsif s.chat.name == 'Facebook Workplace'
          chats.append(s.chat.id)
          notify_params.merge!(
            token: s.token,
            msg: msg,
            mention_to: employee.facebook_workplace,
            mention_to_sub: employee.facebook_workplace_sub,
            mention_in: mention_ins[0],
            mention_name: employee.name
          )
          notify_status = self.notify_to_facebook_workplace(notify_params, s)
        elsif s.chat.name == 'DingTalk'
          chats.append(s.chat.id)
          notify_params.merge!(
            token: s.token,
            msg: msg,
            mention_to: [employee.dingtalk],
            mention_to_sub: [employee.dingtalk_sub],
            mention_in: mention_ins,
            mention_name: employee.name
          )
          notify_status = self.notify_to_dingtalk(notify_params, s)
        elsif s.chat.name == 'Microsoft Teams'
          chats.append(s.chat.id)
          notify_params.merge!(
            token: s.token,
            msg: msg,
            mention_to: employee.ms_teams,
            mention_to_sub: employee.ms_teams_sub,
            mention_in: mention_ins,
            mention_name: employee.name,
            image_url: employee.icon_uri.url
          )
          notify_status = self.notify_to_ms_team(notify_params, s)
        end
      end
    end
  rescue => e
    logger.error(e)
    status = error_with_locale(lang, '.models.notification.failure')
  ensure
    if notify_status
      return notify_status, chats, @@recurrent_info
    else
      return status, chats, @@recurrent_info
    end
  end


  #####################
  # Test Notifications
  #####################
  def self.notify_test(setting_chat)
    status = nil
    if setting_chat.active
      message = setting_chat.chat.name + ' ' + I18n.t('.models.notification.test_notifier')
      mention_in = setting_chat.chat.id == 3 ? setting_chat.token : setting_chat.mention_in # oneteam should use token instead of mention_in
      notifiy_message(setting_chat, mention_in, message)
    else
      status = I18n.t('.models.notification.chat_not_active', chat_name: setting_chat.chat.name)
    end
  rescue => e
    logger.error(e)
    status = I18n.t('.models.notification.test_failure')
  ensure
    return status
  end

  ###################################
  # Notification for monitoring alert
  ###################################

  def self.notify_connection(company, setting_app)
    msg_to_users = "#{setting_app.tablet_location}のiPadとの接続を確認しました。"
    sc = company.setting_chats.find_by(chat_id: setting_app.monitoring_chat_id)
    if sc.active
      mention_in = setting_app.monitoring_mention_in || sc.mention_in
      notifiy_message(sc, mention_in, msg_to_users)
    end
    unless Rails.env.development?
      admin_employees = company.admin_employees
      admin_employees.each do |admin|
        MonitoringMailer.notify_connection(admin, setting_app.tablet_location).deliver_now
      end
    end
    msg_to_house = "下記企業さんのiPadとの接続を確認しました。\n```\n会社名: #{company.name}\nID: #{company.id}\ntablet_location: #{setting_app.tablet_location}\ntablet_uid: #{setting_app.tablet_uid}\n```"
    slack_notifier_init(Rails.application.config.slack_monitoring_token, Rails.application.config.slack_monitoring_channel, false)
    send_slack_notifier(msg_to_house)
    return {result: true}
  end

  def self.notify_disconnection(company, setting_app)
    msg_to_users = "#{setting_app.tablet_location}のiPadとの接続が確認できません。iPadの状況を確認してください。"
    admin_employees = company.admin_employees
    sc = company.setting_chats.find_by(chat_id: setting_app.monitoring_chat_id)
    if sc.active
      mention = ''
      case sc.chat.name
      when 'Slack'
        mention = "<!here>\n"
        admin_employees.each do |admin|
          if sc.authorized && !sc.token.include?("https")
            admin.update_slack_user_id(sc.token) unless admin.slack_user_id
          end
          mention += "#{admin.name + honorific(I18n.locale)} " + slack_format_mention(admin.slack_user_id, sc.token, sc.authorized) + "\n"
        end
      when 'Chatwork'
        admin_employees.each do |admin|
          unless admin.cw_account_id
            account_id = sc.get_account_id(admin.cw_id)
            admin.update(cw_account_id: account_id) if account_id
          end
          mention += "#{admin.name + honorific(I18n.locale)} ([To:#{admin.cw_account_id}])\n"
        end
      when 'Oneteam'
        admin_employees.each do |admin|
          mention += "#{admin.name + honorific(I18n.locale)} (@#{admin.one_team})\n"
        end
      when 'Facebook Workplace'
        admin_employees.each do |admin|
          mention += "#{admin.name + honorific(I18n.locale)} (@[#{admin.facebook_workplace}])\n"
        end
      end
      mention_in = setting_app.monitoring_mention_in || sc.mention_in
      notifiy_message(sc, mention_in, mention + "\n" + msg_to_users)
    end
    unless Rails.env.development?
      admin_employees.each do |admin|
        MonitoringMailer.notify_disconnection(admin, setting_app.tablet_location).deliver_now
      end
    end
    msg_to_house = "<!here>\n*下記企業さんでiPadとの接続が切れました。*\n```\n会社名: #{company.name}\nID: #{company.id}\ntablet_location: #{setting_app.tablet_location}\ntablet_uid: #{setting_app.tablet_uid}\n```"
    slack_notifier_init(Rails.application.config.slack_monitoring_token, Rails.application.config.slack_monitoring_channel, false)
    send_slack_notifier(msg_to_house)
    return {result: true}
  end

  #####################
  # Private Methods
  #####################
  private

  def self.notifiy_message(setting_chat, mention_in, message)
    if setting_chat.chat.name == 'Slack'
      authorized = setting_chat.authorized && !setting_chat.token.include?("https")
      slack_notifier_init(setting_chat.token, mention_in, authorized, false)
      if @notifier.kind_of?(SlackNotification)
        response = @notifier.post(message, true)
        raise response['error'] if response['ok'] == false
      else
        @notifier.ping(message, link_names: 1)
      end
      @notifier = nil
    elsif setting_chat.chat.name == 'Chatwork'
      cw_notifier_init(setting_chat.token)
      ChatWork::Message.create(room_id: mention_in, body: message)
    elsif setting_chat.chat.name == 'Oneteam'
      params = {type: 'message', 'body': message}
      url = URI.parse(mention_in) # oneteam expects token in monitoring_mention_in column
      res = Net::HTTP.post_form(url, params)
      raise JSON.parse(res.body)['errors'][0]['message'] if JSON.parse(res.body)['errors']
    elsif setting_chat.chat.name == 'LINE WORKS'
      if setting_chat.company.try(:id) == 703 # ワークスモバイルジャパン 株式会社様用
        uri = URI.parse("https://enterprise-apis.navercorp.com/#{setting_chat.line_works_app_id}/message/sendMessage/v2")
      else
        uri = URI.parse("https://apis.worksmobile.com/#{setting_chat.line_works_app_id}/message/sendMessage/v2")
      end
      send_to_line_works(uri, setting_chat, message, nil, setting_chat.mention_in)
    elsif setting_chat.chat.name == 'Facebook Workplace'
      send_to_facebook_workchat(
        setting_chat,
        message,
        setting_chat.mention_in
      )
    elsif setting_chat.chat.name == 'DingTalk'
      send_to_dingtalk(setting_chat, message)
    elsif setting_chat.chat.name == 'Microsoft Teams'
      uri = URI.parse(setting_chat.token)
      send_to_ms_team(uri, message)
    end
  end

  #エラーメッセージの1時的な多言語化
  def self.error_with_locale(lang, locales)
    I18n.with_locale(lang) do
      I18n.t(locales)
    end
  end

  def self.honorific(locale)
    locale == :ja ? 'さん' : ''
  end

  # 各社員の通知先チャネルを取得
  def self.get_mention_ins(employees, setting_chat)
    mention_ins = []
    if employees.first.company.upgraded_plan?
      employees.each do |employee|
        em = employee.mention_ins.find_by(chat_id: setting_chat.chat.id)
        # 通知先チャネルを優先する。なければsetting_chat
        if setting_chat.chat.name == 'Oneteam' || setting_chat.chat.name == 'Microsoft Teams'
          mention_ins.append(em.try(:mention_in).present? ? em.mention_in : setting_chat.token)
        else
          mention_ins.append(em.try(:mention_in).present? ? em.mention_in : setting_chat.mention_in)
        end
      end
      mention_ins = mention_ins.uniq
    else
      if setting_chat.chat.name == 'Oneteam' || setting_chat.chat.name == 'Microsoft Teams'
        mention_ins = [setting_chat.token]
      else
        mention_ins = [setting_chat.mention_in]
      end
    end
  end

  def self.slack_notifier_init(token, mention_in, authorized, interactive=true)
    raise unless token.present?
    channel = mention_in ? mention_in : "#general"
    if authorized
      @notifier = SlackNotification.new(token, channel, interactive)
      @@recurrent_info.merge!({ mention_in: channel })
    else
      @notifier = Slack::Notifier.new(
        token,
        channel: '#' + channel
      )
    end
  end

  def self.slack_format_mention(to, token=nil, authorized=false, sub_group=false, to_sub_name=nil)
    if token.present? && authorized && !SLACK_COMMANDS.include?(to)
      return "<!subteam^#{to}|#{to_sub_name}>" if sub_group && to_sub_name.present?
      return "<@#{to}>"
    end
    SLACK_COMMANDS.include?(to) ? "<!#{to}>" : "@#{to}"
  end

  def self.cw_notifier_init(token)
    raise unless token.present?
    ChatWork.api_key = token
  end

  # localeをみて、メッセージを多少変えている
  # whenが増えてきたら、メソッド作る
  def self.facebook_workplace_custom(msg, to, text, visitor_name, visitor_company, visitor_number, tablet_location, thread_id, setting_chat)
    message = custom_fb_notifier_btn_msg(visitor_company, visitor_name, visitor_number, tablet_location, msg, text, to)
    send_to_facebook_workchat(setting_chat, message, thread_id, to)
  rescue => e
    raise e
    # status = error_with_locale(notify_params[:lang], '.models.notification.slack_failure')
  end

  def self.ms_team_custom(msg, to, text, visitor_name, visitor_company, visitor_number, tablet_location, setting_chat, mention_in)
    at, msg, notifier_message = custom_ms_team_notifier_btn_msg(visitor_company, visitor_name, visitor_number, tablet_location,msg, text, to)
    uri = URI.parse(mention_in)
    send_to_ms_team(uri, notifier_message,at, msg)
  rescue => e
    raise e
    # status = error_with_locale(notify_params[:lang], '.models.notification.slack_failure')
  end

  def self.dingtalk_custom(msg, to, text, visitor_name, visitor_company, visitor_number, tablet_location, setting_chat, mention_in)
    notifier_message = custom_dingtalk_notifier_btn_msg(visitor_company, visitor_name, visitor_number, tablet_location,msg, text, to)
    send_to_dingtalk(setting_chat, notifier_message, to)
  rescue => e
    raise e
  end

  def self.line_works_custom(msg, to, text, visitor_name, visitor_company, visitor_number, tablet_location, setting_chat)
    notifier_message = custom_notifier_btn_msg(visitor_company, visitor_name, visitor_number, tablet_location,msg, text, to)
    if setting_chat.company.try(:id) == 703 # ワークスモバイルジャパン 株式会社様用
      uri = URI.parse("https://enterprise-apis.navercorp.com/#{setting_chat.line_works_app_id}/message/sendMessage/v2")
    else
      uri = URI.parse("https://apis.worksmobile.com/#{setting_chat.line_works_app_id}/message/sendMessage/v2")
    end
    send_to_line_works(uri, setting_chat, notifier_message, to, setting_chat.mention_in)
  end

  def self.one_team_custom(msg, to, text, visitor_name, visitor_company, visitor_number,tablet_location, token)
    notifier_message = custom_notifier_btn_msg(visitor_company, visitor_name, visitor_number, tablet_location,msg, text, to)
    url = URI.parse(token)
    params = {type: 'message', body: notifier_message}
    res = Net::HTTP.post_form(url, params)
    raise JSON.parse(res.body)['errors'][0]['message'] if JSON.parse(res.body)['errors']
  end

  def self.slack_custom(msg, to, text, visitor_name, visitor_company, visitor_number, slack_group, slack_group_id, tablet_location, token, authorized)
    at = ""
    if slack_group
      at = "<!subteam^#{slack_group_id}|#{to}>: \n"
    elsif !to.blank?
      at = slack_format_mention(to, token, authorized) + ": \n"
    end

    case I18n.locale
    when :en
      visitor_company = visitor_company ? " of #{visitor_company}" : ""
      visitor_name = visitor_name.presence || "the client"
      visitor_number = visitor_number ? " with group of " + visitor_number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      visitor_company ? visitor_company += "の" : visitor_company = ""
      visitor_name ? visitor_name += "様が" : visitor_name = "お客様が"
      visitor_number ? visitor_number = visitor_number.to_s + "名で" : visitor_number = ""
      tablet_location ? tablet_location += "に、" : tablet_location = ""
    end

    notifier_message = at + I18n.t("models.notification.msgs.slack_custom", tablet_location: tablet_location, text: text, visitor_company: visitor_company, visitor_name: visitor_name, visitor_number: visitor_number, msg: msg)
    send_slack_notifier(notifier_message)
  end

  def self.fb_wp_with_code_msg(msg, to, room, visitor_number, tablet_location)
    case I18n.locale
    when :en
      visitor_number = visitor_number ? "with group of " + visitor_number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      visitor_number ? visitor_number = visitor_number.to_s + "名で" : visitor_number = ""
      tablet_location ? tablet_location += "に、" : tablet_location = ""
    end
    if to.is_a?(Array)
      tos = ""
      to.map do |t, n, sub|
        if sub.present?
          # tos += "#{n + honorific(I18n.locale)} (@[#{t}] & @[#{sub}]) \n"
          tos += "#{n + honorific(I18n.locale)} \n"
        else
          # tos += "#{n + honorific(I18n.locale)} (@[#{t}]) \n"
          tos += "#{n + honorific(I18n.locale)} \n"
        end
      end
      if room.blank?
        notifier_message = I18n.t("models.notification.msgs.facebook_with_code_multi_without_room", tos: tos, tablet_location: tablet_location, visitor_number: visitor_number, msg: msg)
      else
        notifier_message = I18n.t("models.notification.msgs.facebook_with_code_multi", tos: tos, tablet_location: tablet_location, visitor_number: visitor_number, room: room, msg: msg)
      end
    else
      to = "" if to.nil?
      if room.blank?
        notifier_message = to + I18n.t("models.notification.msgs.facebook_with_code_solo_without_room", tablet_location: tablet_location, visitor_number: visitor_number, msg: msg)
      else
        notifier_message = to + I18n.t("models.notification.msgs.facebook_with_code_solo", tablet_location: tablet_location, visitor_number: visitor_number, room: room, msg: msg)
      end
    end
  end

  def self.facebook_workplace_with_code(msg, to, room, visitor_number, tablet_location, thread_id, setting_chat)
    notifier_message = fb_wp_with_code_msg(msg, to, room, visitor_number, tablet_location)
    user_ids = []
    to.map do |t, n, sub|
      user_ids << t
      user_ids << sub if sub
    end
    send_to_facebook_workchat(setting_chat, notifier_message, thread_id, user_ids)
    rescue => e
      raise e
  end

  def self.ms_team_with_code(msg, to, room, visitor_number, tablet_location, notify_params, mention_in)
   case I18n.locale
    when :en
      visitor_number = visitor_number ? "with group of " + visitor_number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      visitor_number ? visitor_number = visitor_number.to_s + "名で" : visitor_number = ""
      tablet_location ? tablet_location += "に、" : tablet_location = ""
    end

    if to.is_a?(Array)
      tos = ""
      to.map do |t, n, sub|
        if sub.present?
          tos += "#{n}さん (@#{t} & @#{sub}) \n\n"
        else
          tos += "#{n}さん (@#{t}) \n\n"
        end
      end
      to = tos
    end
    if room.blank?
      notifier_message = I18n.t("models.notification.msgs.ms_team_with_code_solo_without_room", tablet_location: tablet_location, visitor_number: visitor_number)
    else
      notifier_message = I18n.t("models.notification.msgs.ms_team_with_code_solo", tablet_location: tablet_location, visitor_number: visitor_number, room: room)
    end
    uri = URI.parse(mention_in)
    send_to_ms_team(uri, notifier_message, to, msg, notify_params["image_url"])
  end

  def self.dingtalk_with_code(msg, to, room, visitor_number, tablet_location,notify_params,setting_chat)
   case I18n.locale
    when :en
      visitor_number = visitor_number ? "with group of " + visitor_number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      visitor_number ? visitor_number = visitor_number.to_s + "名で" : visitor_number = ""
      tablet_location ? tablet_location += "に、" : tablet_location = ""
    end
    mention_to = []
    if to.is_a?(Array)
      to.each do |t, n, sub|
        if sub.present?
          mention_to << t
          mention_to << sub
        else
          mention_to << t
        end
      end
      # tos = ""
      # to.map do |t, n, sub|
      #   if sub.present?
      #     tos += "#{n}さん (@[#{t}] & @[#{sub}]) \n"
      #   else
      #     tos += "#{n}さん (@[#{t}]) \n"
      #   end
      # end
      if room.blank?
        notifier_message = I18n.t("models.notification.msgs.dingtalk_with_code_multi_without_room", tablet_location: tablet_location, visitor_number: visitor_number, msg: msg)
      else
        notifier_message = I18n.t("models.notification.msgs.dingtalk_with_code_multi", tablet_location: tablet_location, visitor_number: visitor_number, room: room, msg: msg)
      end
    else
      mention_to << to
      if room.blank?
        notifier_message = I18n.t("models.notification.msgs.dingtalk_with_code_solo_without_room", tablet_location: tablet_location, visitor_number: visitor_number, msg: msg)
      else
        notifier_message = I18n.t("models.notification.msgs.dingtalk_with_code_multi", tablet_location: tablet_location, visitor_number: visitor_number, room: room, msg: msg)
      end
    end
    send_to_dingtalk(setting_chat, notifier_message, mention_to.compact.uniq)
  end

  def self.line_works_with_code(msg, to, room, visitor_number, tablet_location, m_in, setting_chat, notify_params)
    mention_in = []
    case I18n.locale
    when :en
      visitor_number = visitor_number ? "with group of " + visitor_number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      visitor_number ? visitor_number = visitor_number.to_s + "名で" : visitor_number = ""
      tablet_location ? tablet_location += "に、" : tablet_location = ""
    end
    if setting_chat.company.try(:id) == 703 # ワークスモバイルジャパン 株式会社様用
      uri = URI.parse("https://enterprise-apis.navercorp.com/#{setting_chat.line_works_app_id}/message/sendMessage/v2")
    else
      uri = URI.parse("https://apis.worksmobile.com/#{setting_chat.line_works_app_id}/message/sendMessage/v2")
    end
    if to.is_a?(Array)
      tos = ""
      to.map do |t, n, sub|
        if t
          if sub.present?
            mention_in << sub
            mention_in << t
            tos += "#{n}さん (#{t} & #{sub}) \n"
          else
            mention_in << t
            tos += "#{n}さん (#{t}) \n"
          end
        end
      end
      if room.blank?
        notifier_message = I18n.t("models.notification.msgs.line_works_with_code_multi_without_room", tos: tos, tablet_location: tablet_location, visitor_number: visitor_number, msg: msg)
      else
        notifier_message = I18n.t("models.notification.msgs.line_works_with_code_multi", tos: tos, tablet_location: tablet_location, visitor_number: visitor_number, room: room, msg: msg)
      end
    else
      if room.blank?
        notifier_message = I18n.t("models.notification.msgs.line_works_with_code_solo_without_room", to: to, tablet_location: tablet_location, visitor_number: visitor_number, msg: msg)
      else
        notifier_message = I18n.t("models.notification.msgs.line_works_with_code_solo", to: to, tablet_location: tablet_location, visitor_number: visitor_number, room: room, msg: msg)
      end
    end
    send_to_line_works(uri, setting_chat, notifier_message, mention_in, notify_params[:group_id])
  end

  def self.one_team_with_code(msg, to, room, visitor_number, tablet_location, url, mention_in)
    case I18n.locale
    when :en
      visitor_number = visitor_number ? "with group of " + visitor_number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      visitor_number ? visitor_number = visitor_number.to_s + "名で" : visitor_number = ""
      tablet_location ? tablet_location += "に、" : tablet_location = ""
    end

    if to.is_a?(Array)
      tos = ""
      to.map do |t, n, sub|
        if sub.present?
          tos += "#{n + honorific(I18n.locale)} (@#{t} & @#{sub}) \n"
        else
          tos += "#{n + honorific(I18n.locale)} (@#{t}) \n"
        end
      end
      if room.blank?
        notifier_message = I18n.t("models.notification.msgs.one_team_with_code_multi_without_room", tos: tos, tablet_location: tablet_location, visitor_number: visitor_number, msg: msg)
      else
        notifier_message = I18n.t("models.notification.msgs.one_team_with_code_multi", tos: tos, tablet_location: tablet_location, visitor_number: visitor_number, room: room, msg: msg)
      end
    else
      if room.blank?
        notifier_message = I18n.t("models.notification.msgs.one_team_with_code_solo_without_room", to: to, tablet_location: tablet_location, visitor_number: visitor_number, msg: msg)
      else
        notifier_message = I18n.t("models.notification.msgs.one_team_with_code_solo", to: to, tablet_location: tablet_location, visitor_number: visitor_number, room: room, msg: msg)
      end
    end
    url = URI.parse(mention_in)
    params = {type: 'message', body: notifier_message}
    res = Net::HTTP.post_form(url, params)
    raise JSON.parse(res.body)['errors'][0]['message'] if JSON.parse(res.body)['errors']
  end

  def self.slack_with_code(msg, to, room, visitor_number, tablet_location, token, authorized)
    case I18n.locale
    when :en
      visitor_number = visitor_number ? "with group of " + visitor_number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      visitor_number ? visitor_number = visitor_number.to_s + "名で" : visitor_number = ""
      tablet_location ? tablet_location += "に、" : tablet_location = ""
    end

    if to.is_a?(Array)
      tos = ""
      to.map do |t, n, sub, sub_group, mention_to_sub_name|
        if sub.present?
          tos += "#{n + honorific(I18n.locale)} (" + slack_format_mention(t, token, authorized) + " & " + slack_format_mention(sub, token, authorized, sub_group, mention_to_sub_name) + ") \n"
        else
          tos += "#{n + honorific(I18n.locale)} (" + slack_format_mention(t, token, authorized) + ") \n"
        end
      end
      if room.blank?
        notifier_message = I18n.t("models.notification.msgs.slack_with_code_multi_without_room", tos: tos, tablet_location: tablet_location, visitor_number: visitor_number, msg: msg)
      else
        notifier_message = I18n.t("models.notification.msgs.slack_with_code_multi", tos: tos, tablet_location: tablet_location, visitor_number: visitor_number, room: room, msg: msg)
      end
      send_slack_notifier(notifier_message)
    else
      if room.blank?
        notifier_message = I18n.t("models.notification.msgs.slack_with_code_solo_without_room", to: to, tablet_location: tablet_location, visitor_number: visitor_number, msg: msg)
      else
        notifier_message = I18n.t("models.notification.msgs.slack_with_code_solo", to: to, tablet_location: tablet_location, visitor_number: visitor_number, room: room, msg: msg)
      end
      send_slack_notifier(notifier_message)
    end
  end

  def self.one_team_without_code(msg, to, to_sub, company_name, name, number, mention_name, tablet_location, url, mention_in)
    if to_sub.present?
      to ? at = "#{mention_name + honorific(I18n.locale)}(@#{to} & @#{to_sub}) \n" : at = ""
    else
      to ? at = "#{mention_name + honorific(I18n.locale)}(@#{to}) \n" : at = ""
    end

    case I18n.locale
    when :en
      company_name = company_name ? "of #{company_name}" : ""
      name = name.presence || "the client"
      number = number ? "with group of " + number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      company_name ? company_name += "の" : company_name = ""
      name ? name += "様が" : name = "お客様が"
      number ? number = number.to_s + "名で" : number = ""
      tablet_location ? tablet_location += "に、" : tablet_location = ""
    end

    notifier_message = at + I18n.t("models.notification.msgs.one_team_without_code", tablet_location: tablet_location, company_name: company_name, name: name, number: number, msg: msg)
    mention_in.each do |mi|
      url = URI.parse(mi)
      params = {type: 'message', body: notifier_message}
      res = Net::HTTP.post_form(url, params)
      raise JSON.parse(res.body)['errors'][0]['message'] if JSON.parse(res.body)['errors']
    end
    return
  end

  def self.dingtalk_without_code(msg, to, to_sub, company_name, name, number, mention_name, tablet_location, setting_chat, notify_params)
    # if to_sub.present?
    #   at = to.present? ? "#{mention_name}さん(@[#{to}] & @[#{to_sub}]) \n" : ""
    # else
    #   at = to.present? ? "#{mention_name}さん(@[#{to}]) \n" : ""
    # end

    case I18n.locale
    when :en
      company_name = company_name ? "of #{company_name}" : ""
      name = name.presence || "the client"
      number = number ? "with group of " + number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      company_name ? company_name += "の" : company_name = ""
      name ? name += "様が" : name = "お客様が"
      number ? number = number.to_s + "名で" : number = ""
      tablet_location ? tablet_location += "に、" : tablet_location = ""
    end

    # notifier_message = at + I18n.t("models.notification.msgs.facebook_without_code", tablet_location: tablet_location, company_name: company_name, name: name, number: number, msg: msg)
    notifier_message = I18n.t("models.notification.msgs.dingtalk_without_code", tablet_location: tablet_location, company_name: company_name, name: name, number: number, msg: msg)
    # notify_params[:mention_in].each do |mi|
      begin
        send_to_dingtalk(setting_chat, notifier_message, to)
      rescue => e
        raise e
      end
    # end
    return
  end

  def self.fb_wp_without_code_message(msg, to, to_sub, company_name, name, number, mention_name, tablet_location)
    if to_sub.present?
      # at = to.present? ? "#{mention_name + honorific(I18n.locale)}(@[#{to}] & @[#{to_sub}]) \n" : ""
      at = to.present? ? "#{mention_name + honorific(I18n.locale)} \n" : ""
    else
      # at = to.present? ? "#{mention_name + honorific(I18n.locale)}(@[#{to}]) \n" : ""
      at = to.present? ? "#{mention_name + honorific(I18n.locale)} \n" : ""
    end
    case I18n.locale
    when :en
      company_name = company_name ? "of #{company_name}" : ""
      name = name.presence || "the client"
      number = number ? "with group of " + number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      company_name ? company_name += "の" : company_name = ""
      name ? name += "様が" : name = "お客様が"
      number ? number = number.to_s + "名で" : number = ""
      tablet_location ? tablet_location += "に、" : tablet_location = ""
    end

    notifier_message = at + I18n.t("models.notification.msgs.facebook_without_code", tablet_location: tablet_location, company_name: company_name, name: name, number: number, msg: msg)
  end

  def self.facebook_workplace_without_code(msg, to, to_sub, company_name, name, number, mention_name, tablet_location, thread_id, setting_chat)
    message = fb_wp_without_code_message(msg, to, to_sub, company_name, name, number, mention_name, tablet_location)
    user_ids = [to]
    user_ids << to_sub if to_sub
    send_to_facebook_workchat(setting_chat, message, thread_id, user_ids)
    rescue => e
      raise e
  end

  def self.ms_team_without_code(msg, to, to_sub, company_name, name, number, mention_name, tablet_location, setting_chat, notify_params)
    if to_sub.present?
      at = to.present? ? "#{mention_name}さん(@#{to} & @#{to_sub}) \n\n" : ""
    else
      at = to.present? ? "#{mention_name}さん(@#{to}) \n\n" : ""
    end

    case I18n.locale
    when :en
      company_name = company_name ? "of #{company_name}" : ""
      name = name.presence || "the client"
      number = number ? "with group of " + number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      company_name ? company_name += "の" : company_name = ""
      name ? name += "様が" : name = "お客様が"
      number ? number = number.to_s + "名で" : number = ""
      tablet_location ? tablet_location += "に、" : tablet_location = ""
    end
    notifier_message = I18n.t("models.notification.msgs.ms_team_without_code", tablet_location: tablet_location, company_name: company_name, name: name, number: number)
    # notifier_message = I18n.t("models.notification.msgs.ms_team_without_code", tablet_location: tablet_location, company_name: company_name, name: name, number: number, msg: msg)
    notify_params[:mention_in].each do |mi|
      begin
        uri = URI.parse(mi)
        send_to_ms_team(uri, notifier_message, at, msg, notify_params["image_url"])
      rescue => e
        raise e
      end
    end
    return
  end

  def self.line_works_without_code(msg, to, to_sub, company_name, name, number, mention_name, tablet_location, setting_chat, notify_params)
    tos = []
    if to
      if to_sub.present?
        tos << to_sub
        tos << to
        at = "#{mention_name}さん(#{to} & #{to_sub}) \n"
      else
        tos << to
        at = "#{mention_name}さん(#{to}) \n"
      end
    else
      at = "#{mention_name}さん \n"
    end
    case I18n.locale
    when :en
      company_name = company_name ? "of #{company_name}" : ""
      name = name.presence || "the client"
      number = number ? "with group of " + number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      company_name ? company_name += "の" : company_name = ""
      name ? name += "様が" : name = "お客様が"
      number ? number = number.to_s + "名で" : number = ""
      tablet_location ? tablet_location += "に、" : tablet_location = ""
    end
    notifier_message = at + I18n.t("models.notification.msgs.line_works_without_code", tablet_location: tablet_location, company_name: company_name, name: name, number: number, msg: msg)
    if setting_chat.company.try(:id) == 703 # ワークスモバイルジャパン 株式会社様用
      uri = URI.parse("https://enterprise-apis.navercorp.com/#{setting_chat.line_works_app_id}/message/sendMessage/v2")
    else
      uri = URI.parse("https://apis.worksmobile.com/#{setting_chat.line_works_app_id}/message/sendMessage/v2")
    end
    send_to_line_works(uri, setting_chat, notifier_message, tos, notify_params[:group_id])
  end

  def self.slack_without_code(msg, to, to_sub, company_name, name, number, mention_name, tablet_location, token, authorized, sub_group, mention_to_sub_name)
    if SLACK_COMMANDS.include?(to)
      to ? at = "" + slack_format_mention(to) + ": \n" : at = ""
    else
      if to_sub.present?
        to ? at = "#{mention_name + honorific(I18n.locale)} (" + slack_format_mention(to, token, authorized) + " & " + slack_format_mention(to_sub, token, authorized, sub_group, mention_to_sub_name) + ") \n" : at = ""
      else
        to ? at = "#{mention_name + honorific(I18n.locale)} (" + slack_format_mention(to, token, authorized) + ") \n" : at = ""
      end
    end

    case I18n.locale
    when :en
      company_name = company_name ? " of #{company_name}" : ""
      name = name.presence || "the client"
      number = number ? " with group of " + number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      company_name ? company_name += "の" : company_name = ""
      name ? name += "様が" : name = "お客様が"
      number ? number = number.to_s + "名で" : number = ""
      tablet_location ? tablet_location += "に、" : tablet_location = ""
    end

    notifier_message = at + I18n.t("models.notification.msgs.slack_without_code", tablet_location: tablet_location, company_name: company_name, name: name, number: number, msg: msg)
    send_slack_notifier(notifier_message)
  end

  def self.send_slack_notifier(msg)
    if @notifier.kind_of?(SlackNotification)
      notification = Notification.create(company_id: @@recurrent_info[:company_id])
      if @@recurrent_info[:active]
        date = Date.today.strftime("%Y%m%d")
        @@recurrent_info.merge!({ msg: msg, date: date, notification_id: notification.id })
        msg = "[#{date}-#{@@recurrent_info[:count]}]\n" + msg
      end
      response = @notifier.post(msg, notification.id)
      if response['ok'] == false
        notification.delete
        raise response['error']
      else
        timestamp = response['ts']
        @@redis.set(notification.id, [timestamp])
      end
    else
      @notifier.ping(msg, link_names: 1)
    end
  end

  def self.cw_custom(msg, mention_in, to, text, visitor_name, visitor_company, visitor_number, tablet_location)
    if to.present?
      at = ""
      to.map{ |t| at += "[To:#{t}][pname:#{t}]: \n" }
    else
      at = ""
    end

    case I18n.locale
    when :en
      visitor_company = visitor_company ? "of #{visitor_company}" : ""
      visitor_name = visitor_name.presence || "the client"
      visitor_number = visitor_number ? "with group of " + visitor_number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      tablet_location ? tablet_location += "に、" : tablet_location = ""
      visitor_company ? visitor_company += "の" : visitor_company = ""
      visitor_name ? visitor_name += "様が" : visitor_name = "お客様が"
      visitor_number ? visitor_number = visitor_number.to_s + "名で" : visitor_number = ""
    end
    to = to.present? ? "[To:#{to}]:" : ""

    notifier_message = at + I18n.t("models.notification.msgs.cw_custom", tablet_location: tablet_location, text: text, visitor_company: visitor_company, visitor_name: visitor_name, visitor_number: visitor_number, msg: msg)
    ChatWork::Message.create(room_id: mention_in, body: notifier_message)
  end

  def self.cw_with_code(msg, mention_in, to, room, visitor_number, tablet_location)
    case I18n.locale
    when :en
      visitor_number = visitor_number ? "with group of " + visitor_number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      visitor_number ? visitor_number = visitor_number.to_s + "名で" : visitor_number = ""
      tablet_location ? tablet_location += "に、" : tablet_location = ""
    end

    if to.is_a?(Array)
      tos = ""
      to.map do|t, n, sub|
        if sub.present?
          tos += "#{n + honorific(I18n.locale)}([To:#{t}] & [To:#{sub}]) \n"
        else
          tos += "#{n + honorific(I18n.locale)}([To:#{t}]) \n"
        end
      end
      if room.blank?
        notifier_message = I18n.t("models.notification.msgs.cw_with_code_multi_without_room", tos: tos, tablet_location: tablet_location, visitor_number: visitor_number, msg: msg)
      else
        notifier_message = I18n.t("models.notification.msgs.cw_with_code_multi", tos: tos, tablet_location: tablet_location, visitor_number: visitor_number, room: room, msg: msg)
      end
      ChatWork::Message.create(room_id: mention_in, body: notifier_message)
    else
      if room.blank?
        notifier_message = I18n.t("models.notification.msgs.cw_with_code_solo_without_room", to: to, tablet_location: tablet_location, visitor_number: visitor_number, msg: msg)
      else
        notifier_message = I18n.t("models.notification.msgs.cw_with_code_solo", to: to, tablet_location: tablet_location, visitor_number: visitor_number, room: room, msg: msg)
      end
      ChatWork::Message.create(room_id: mention_in, body: notifier_message)
    end
  end

  def self.cw_without_code(msg, mention_in, to, to_sub, company_name, name, number, mention_name, tablet_location)
    case I18n.locale
    when :en
      company_name = company_name ? "of #{company_name}" : ""
      name = name.presence || "the client"
      number = number ? "with group of " + number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      tablet_location ? tablet_location += "に、" : tablet_location = ""
      company_name ? company_name += "の" : company_name = ""
      name ? name += "様が" : name = "お客様が"
      number ? number = number.to_s + "名で" : number = ""
    end
    if to_sub.present?
      to ? to = "#{mention_name + honorific(I18n.locale)}([To:#{to}] & [To:#{to_sub}]) \n" : to = ""
    else
      to ? to = "#{mention_name + honorific(I18n.locale)}([To:#{to}]) \n" : to = ""
    end

    notifier_message = to + I18n.t("models.notification.msgs.cw_without_code", tablet_location: tablet_location, company_name: company_name, name: name, number: number, msg: msg)
    ChatWork::Message.create(room_id: mention_in, body: notifier_message)
  end

  def self.custom_fb_notifier_btn_msg(visitor_company, visitor_name, visitor_number, tablet_location, msg, text, to)
    # if to.present?
    #   at = ""
    #   to.map{ |t| at += "@[#{t}]: \n" }
    # else
    #   at = ""
    # end
    at = ""

    case I18n.locale
    when :en
      visitor_company = visitor_company ? "of #{visitor_company}" : ""
      visitor_name = visitor_name.presence || "the client"
      visitor_number = visitor_number ? "with group of " + visitor_number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      visitor_company ? visitor_company += "の" : visitor_company = ""
      visitor_name ? visitor_name += "様が" : visitor_name = "お客様が"
      visitor_number ? visitor_number = visitor_number.to_s + "名で" : visitor_number = ""
      tablet_location ? tablet_location += "に、" : tablet_location = ""
    end

    notifier_message = at + I18n.t("models.notification.msgs.facebook_custom", tablet_location: tablet_location, text: text, visitor_company: visitor_company, visitor_name: visitor_name, visitor_number: visitor_number, msg: msg)
  end

  def self.custom_ms_team_notifier_btn_msg(visitor_company, visitor_name, visitor_number, tablet_location,msg, text, to)
    if to.present?
        at = ""
        to.map{ |t| at += "@#{t}: \n\n" }
    else
      at = ""
    end

    case I18n.locale
    when :en
      visitor_company = visitor_company ? "of #{visitor_company}" : ""
      visitor_name = visitor_name.presence || "the client"
      visitor_number = visitor_number ? "with group of " + visitor_number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      visitor_company ? visitor_company += "の" : visitor_company = ""
      visitor_name ? visitor_name += "様が" : visitor_name = "お客様が"
      visitor_number ? visitor_number = visitor_number.to_s + "名で" : visitor_number = ""
      tablet_location ? tablet_location += "に、" : tablet_location = ""
    end
    notifier_message = I18n.t("models.notification.msgs.ms_team_custom", tablet_location: tablet_location, text: text, visitor_company: visitor_company, visitor_name: visitor_name, visitor_number: visitor_number)
    return at, msg, notifier_message
    # notifier_message = I18n.t("models.notification.msgs.ms_team_custom", tablet_location: tablet_location, text: text, visitor_company: visitor_company, visitor_name: visitor_name, visitor_number: visitor_number, msg: msg)
  end

  def self.custom_dingtalk_notifier_btn_msg(visitor_company, visitor_name, visitor_number, tablet_location,msg, text, to)
    # if to.present?
    #     at = ""
    #     to.map{ |t| at += "@[#{t}]: \n" }
    #   else
    #     at = ""
    #   end

    case I18n.locale
    when :en
      visitor_company = visitor_company ? "of #{visitor_company}" : ""
      visitor_name = visitor_name.presence || "the client"
      visitor_number = visitor_number ? "with group of " + visitor_number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      visitor_company ? visitor_company += "の" : visitor_company = ""
      visitor_name ? visitor_name += "様が" : visitor_name = "お客様が"
      visitor_number ? visitor_number = visitor_number.to_s + "名で" : visitor_number = ""
      tablet_location ? tablet_location += "に、" : tablet_location = ""
    end

    # notifier_message = at + I18n.t("models.notification.msgs.facebook_custom", tablet_location: tablet_location, text: text, visitor_company: visitor_company, visitor_name: visitor_name, visitor_number: visitor_number, msg: msg)
    notifier_message = I18n.t("models.notification.msgs.dingtalk_custom", tablet_location: tablet_location, text: text, visitor_company: visitor_company, visitor_name: visitor_name, visitor_number: visitor_number, msg: msg)
  end

  # message to be sent when clicking on the custom btn in the receptionist app
  def self.custom_notifier_btn_msg(visitor_company, visitor_name, visitor_number, tablet_location,msg, text, to)
    case I18n.locale
    when :en
      visitor_company = visitor_company ? "of #{visitor_company}" : ""
      visitor_name = visitor_name.presence || "the client"
      visitor_number = visitor_number ? "with group of " + visitor_number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      visitor_company ? visitor_company += "の" : visitor_company = ""
      visitor_name ? visitor_name += "様が" : visitor_name = "お客様が"
      visitor_number ? visitor_number = visitor_number.to_s + "名で" : visitor_number = ""
      tablet_location ? tablet_location += "に、" : tablet_location = ""
    end
    if to.present?
        at = ""
        to.map{ |t| at += "@#{t}: \n" }
    else
        at = ""
    end
    at + " " + I18n.t("models.notification.msgs.one_team_custom", tablet_location: tablet_location, text: text, visitor_company: visitor_company, visitor_name: visitor_name, visitor_number: visitor_number, msg: msg)
  end

  def self.without_code_notifier_fb_btn_msg(company_name, name, number, tablet_location, at, msg)
    case I18n.locale
    when :en
      company_name = company_name ? "of #{company_name}" : ""
      name = name.presence || "the client"
      number = number ? "with group of " + number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      company_name = company_name ? "の" : ""
      name = name ? "様が" : "お客様が"
      number = number ? number.to_s + "名で" : ""
      tablet_location = tablet_location ?  "に、" :  ""
    end
    at + ' '+ I18n.t("models.notification.msgs.fb_without_code", tablet_location: tablet_location, company_name: company_name, name: name, number: number, msg: msg)
  end

  # message to be sent when clicking on the notifier type 2 btn in the receptionist app
  def self.without_code_notifier_btn_msg(company_name, name, number, tablet_location, at, msg)
    case I18n.locale
    when :en
      company_name = company_name ? "of #{company_name}" : ""
      name = name.presence || "the client"
      number = number ? "with group of " + number.to_s  : ""
      tablet_location = tablet_location ? "[#{tablet_location}]" : ""
    when :ja
      company_name = company_name ? "の" : ""
      name = name ? "様が" : "お客様が"
      number = number ? number.to_s + "名で" : ""
      tablet_location = tablet_location ?  "に、" :  ""
    end
    at + ' '+ I18n.t("models.notification.msgs.one_team_without_code", tablet_location: tablet_location, company_name: company_name, name: name, number: number, msg: msg)
  end

  def self.send_to_facebook_workchat(setting_chat, message, thread_id=nil, user_ids=[])
    uri = URI.parse("https://graph.facebook.com/me/messages")
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Post.new(uri.path)
    token = setting_chat.token
    req['Authorization'] = "Bearer #{token}"
    req['Content-Type'] = 'application/json'
    thread_id = thread_id || setting_chat.mention_in # set default thread id if nil
    req.body = {
                "recipient": {
                  "thread_key": thread_id
                },
                "message": {
                  'text': message
                }
              }.to_json
    res = https.request(req)
    raise JSON.parse(res.body)['error']['message'] if JSON.parse(res.body)['error']

    if user_ids.present?
      req.body = {
        "recipient": {
          "ids": user_ids
        },
        "message": {
          'text': message
        }
      }.to_json
      res = https.request(req)
      # TODO: Catch error for DM
      # raise JSON.parse(res.body)['error']['message'] if JSON.parse(res.body)['error']
    end

    return
  end

  def self.send_to_line_works(uri, setting_chat, message, mention_ins = nil, group_id)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Post.new(uri.path)
    req['consumerKey'] = setting_chat.line_works_consumer_key
    req['Authorization'] = "Bearer #{setting_chat.token}"
    req['Content-Type'] = 'application/json'
    req['charset'] = 'UTF-8'
    if mention_ins.is_a?(Array) && mention_ins.present?
      mention_ins.each do |mention_in|
        req.body = {
                    "botNo" => setting_chat.line_works_bot,
                    "accountId" => "#{mention_in}@#{group_id}",
                    "content" => {
                        "type" => "text",
                        "text" => message
                    }
                }.to_json
        res = https.request(req)
        raise JSON.parse(res.body)['errorMessage'] if JSON.parse(res.body)['errorCode']
      end
    else
      req.body = {
                    "botNo" => setting_chat.line_works_bot,
                    "accountId" => mention_ins.present? ? "#{mention_ins}@#{group_id}" : "#{setting_chat.mention_to}@#{group_id}",
                    "content" => {
                        "type" => "text",
                        "text" => message
                    }
                }.to_json
        res = https.request(req)
        raise JSON.parse(res.body)['errorMessage'] if JSON.parse(res.body)['errorCode']
    end
    return
  end

  def self.send_to_dingtalk(setting_chat, message, notify_params = nil)
    uri = URI.parse("https://oapi.dingtalk.com/robot/send")
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Post.new(setting_chat.token)
    req['Content-Type'] = 'application/json'
    req['charset'] = 'UTF-8'
    req.body = {
                "msgtype": "text",
                "text": {
                    "content": message
                },
                "at": {
                    "atMobiles": notify_params,
                    "isAtAll": false
                }
            }.to_json
    res = https.request(req)
    raise JSON.parse(res.body)['errmsg'] unless JSON.parse(res.body)['errcode'] == 0
    return
  end

  def self.send_to_ms_team(uri, location = nil, at=nil, msg =nil, image_url =nil)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Post.new(uri.path)
    req['Content-Type'] = 'application/json'
    req['charset'] = 'UTF-8'
    req.body = {
      "@type": "MessageCard",
      "@context": "http://schema.org/extensions",
      "themeColor": "1db9b3",
      "text": "![Alt text for the image](https://s3-ap-northeast-1.amazonaws.com/receptionist/static/top-logo.png)",
      "sections": [
          {
              "startGroup": true,
              "title": location,
              "activityImage": image_url,
              "activityTitle": at,
              "activitySubtitle": msg
          }
      ]
    }.to_json
    res = https.request(req)
    raise JSON.parse(res.body) if res.code.to_i >= 400
    return
  end

  def self.get_mention_to(users, setting_chat)
    mention_to = []
    users.each do |user|
      sub_group = false
      mention_name = user.slack
      mention_name_sub = user.slack_sub
      if setting_chat.authorized && !setting_chat.token.include?("https")
        user.update_slack_user_id(setting_chat.token)
        mention_name = user.slack_user_id if user.slack_user_id
        if mention_name_sub.present?
          result = SlackApi.get_user_id(setting_chat.token, user.slack_sub)
          unless result[:ok]
            result = SlackApi.get_group_id(setting_chat.token, user.slack_sub)
            sub_group = true
          end
          mention_name_sub = result[:slack_user_id]
        end
      end
      mention_to.push([mention_name, user.name, mention_name_sub, sub_group, user.slack_sub])
    end
    mention_to
  end
end
