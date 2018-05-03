require 'fcm'
class Api::EmployeesController < ApplicationController
  before_action :login_employee_only!, except: [:check_admin_domain] unless Rails.env.development?
  after_action :active!, only: :registration
  before_action :prepare_company, only: [:show_me, :index, :update]
  after_action :delete_emp_list_cache, only: :update unless Rails.env.test?
  before_action :build_emp_google, only: [:gc_auth, :gc_auth_with_code, :gc_info]
  before_action :check_emp_google, only: :gc_info
=begin
  @api {get} /api/employee/show_me ShowMe
  @apiName ShowMe
  @apiGroup Employee
  @apiDescription 自分の社員情報の取得
  @apiPermission general

  @apiSuccess {Object} employee
  @apiSuccess {String} employee.uqid 社員ID
  @apiSuccess {String} employee.email メール
  @apiSuccess {String} employee.name 名前
  @apiSuccess {String} employee.name_reading カナ
  @apiSuccess {String} employee.first_name FirstName
  @apiSuccess {String} employee.last_name LastName
  @apiSuccess {String} employee.name_reading_en 英語
  @apiSuccess {String} employee.icon_uri プロフィール画像
  @apiSuccess {String} employee.department 部署
  @apiSuccess {String} employee.slack Slack ID
  @apiSuccess {String} employee.cw_id Chatwork ID
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {
      employee: {
        uqid: "123456",
        email: "host@example.com",
        uid: "host@example.com",
        name: "name",
        name_reading: "name",
        first_name: "first_name",
        last_name: "last_name",
        name_reading_en: "name",
        email: "example@example.com",
        icon_uri {
          uri; null,
          thumb: {
            uri: null
          }
        },
        department: "部署",
        active: true,
        slack: "slack",
        cw_id: "cw_id",
      },
      company: {
        uid: "uid",
        name: "company name",
        name_reading_en: "company english name",
        zip_zode: "郵便番号",
        address1: "都道府県市町村区",
        address2: "番地 建物名",
        phone_no: "電話番号",
        plan_status: "スタンダード",
        count: 10,
        admin_name: "admin_name",
        corporate_url: "http://example.com",
      }
    }
  @apiUse NotFound
=end
  def show_me
    render json: current_api_employee, meta: { is_enterprise: @company.upgraded_plan? }, status: 200
  end

  def trigger_alarm
    FirebaseCloudMessagingService.trigger_alarm(current_api_employee)
  end


=begin
  @api {get} /api/company/employees IndexEmployees
  @apiName IndexEmployees
  @apiGroup Company
  @apiDescription 社員一覧の取得
  @apiPermission admin

  @apiParam {String} filter_id {1: 設定が完了していない社員, 2: メール認証が終わっていない社員}
  @apiParam {Boolean} both_filter 設定が完了していないもしくはメール認証が終わっていない社員

  @apiSuccess {Object} employee
  @apiSuccess {String} employee.uqid 社員ID
  @apiSuccess {String} employee.email メール
  @apiSuccess {String} employee.name 名前
  @apiSuccess {String} employee.name_reading カナ
  @apiSuccess {String} employee.first_name FirstName
  @apiSuccess {String} employee.last_name LastName
  @apiSuccess {String} employee.name_reading_en 英語
  @apiSuccess {String} employee.icon_uri プロフィール画像
  @apiSuccess {String} employee.department 部署
  @apiSuccess {String} employee.slack Slack ID
  @apiSuccess {String} employee.cw_id Chatwork ID
  @apiSuccess {String} company.active 登録状況
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {
      employees: {
        uqid: "1234556"
        email: "host@example.com"
        uid: "host@example.com"
        name: "name"
        name_reading: "name"
        first_name: "first_name"
        last_name: "last_name"
        name_reading_en: "name"
        email: "example@example.com"
        icon_uri {
          uri; null
          thumb: {
            uri: null
          }
        }
        department: "部署"
        active: true
        slack: "slack"
      }
    }

  @apiUse Unauthorized
=end
  def index
    if params[:filter_id].to_i == 1
      employees = Rails.cache.fetch(cache_key('filtered'), expires_in: 20.minutes) do
        @company.employees.notification_unavailable.to_a
      end
    else
      employees = Rails.cache.fetch(cache_key(), expires_in: 20.minutes) do
        @company.employees.includes(:mention_ins, :chats).to_a
      end
    end

    if params[:page]
      employees = Kaminari.paginate_array(employees).page(params[:page].to_i).per(20)
      render json: employees, meta: {total_pages: employees.total_pages, current_page: employees.current_page, is_enterprise: @company.upgraded_plan? }, status: 200
    else
      render json: employees, status: 200
    end

  end

=begin
  @api {put} /api/employee UpdateEmployee
  @apiName UpdateEmployee
  @apiGroup Employee
  @apiDescription 社員情報の更新
  @apiPermission general

  @apiParam {Object} employee
  @apiParam {String} [employee.email] メールアドレス
  @apiParam {String} [employee.name] 管理者名
  @apiParam {String} [employee.name_reading] 読み仮名
  @apiParam {String} [employee.first_name] FirstName
  @apiParam {String} [employee.last_name] LastName
  @apiParam {String} [employee.password] パスワード
  @apiParam {String} [employee.slack] Slack ID
  @apiParam {String} [employee.cw_id] Chatwork ID
  @apiParam {String} [employee.icon_url] アイコン画像
  @apiParam {String[]} mentions 社員別通知先チャネル (エンタープライズのみ)
  @apiParam {String} mentions.chat_id チャットID
  @apiParam {String} mentions.mention_id 通知先チャネル

  @apiSuccess {Object} employee
  @apiSuccess {String} employee.uqid 社員ID
  @apiSuccess {String} employee.email メール
  @apiSuccess {String} employee.name 名前
  @apiSuccess {String} employee.first_name FirstName
  @apiSuccess {String} employee.last_name LastName
  @apiSuccess {String} employee.slack Slack ID
  @apiSuccess {String} employee.cw_id Chatwork ID
  @apiSuccess {String} company.active 登録状況
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {
      employee: {
        uqid: "123456"
        email: "host@example.com"
        uid: "host@example.com"
        name: "name"
        name_reading: "name"
        first_name: "first_name"
        last_name: "last_name"
        name_reading_en: "name"
        email: "example@example.com"
        icon_uri {
          uri; null
          thumb: {
            uri: null
          }
        }
        department: "部署"
        active: true
        slack: "slack"
      }
    }
  @apiUse NotFound
=end
  def update
    if current_api_employee.should_get_slack_user_id?(update_params)
      render_error('E04011', 'slack_user_id_not_found', 422) and return unless current_api_employee.update_slack_user_id(@company.setting_chat_slack.token, update_params[:slack])
    end
    if current_api_employee.should_get_slack_user_id_sub?(update_params)
      render_error('E04011', 'slack_user_id_sub_not_found', 422) and return unless current_api_employee.update_slack_user_id_sub(@company.setting_chat_slack.token, update_params[:slack_sub])
    end
    # TODO: deal with migration of employee mentions table
    cw_mention_in = params[:mentions].present? ? params[:mentions].find{|m| m[:chat][:id].to_i == 2} : nil
    sc = @company.get_setting_chat('Chatwork')
    cw_update_type = sc.get_cw_update_type(current_api_employee, cw_mention_in, update_params) # determine if cw related columns should be updated

    if cw_update_type
      if update_params[:cw_id] && sc.mention_in && sc.token
        # get chatwork id and account
        attributes = sc.update_cw_ids(cw_update_type, cw_mention_in, update_params)
        if attributes
          current_api_employee.update_attributes!(attributes) # update if no fail calling chatwork api
          current_api_employee.update_mentions(params[:mentions]) if @company.upgraded_plan?
          render_success(current_api_employee)
        else
          render_error('E04010', 'cw_account_not_found', 422)
        end
      else
        render_error('E04011', 'cw_info_not_found', 422)
      end
    else
      current_api_employee.update_attributes!(update_params)
      current_api_employee.update_mentions(params[:mentions]) if @company.upgraded_plan?
      render_success(current_api_employee)
    end
  end

=begin
  @api {put} /api/employee/gc_auth GoogleCalendarIntegration
  @apiName GoogleCalendarIntegration
  @apiGroup Employee
  @apiDescription GoogleCalendar連携
  @apiPermission general

  @apiParam {Boolean} gc_switch

  @apiSuccess {Object} employee
  @apiSuccess {String} employee.uqid 社員ID
  @apiSuccess {String} employee.email メール
  @apiSuccess {String} employee.name 名前
  @apiSuccess {String} employee.slack slack名
  @apiSuccess {String} company.active 登録状況
  @apiSuccessExample Success-Response:
    HTTP/1.1 201 OK
    {
      employee: {
        uqid: "123456"
        email: "host@example.com"
        uid: "host@example.com"
        name: "name"
        name_reading: "name"
        first_name: "first_name"
        last_name: "last_name"
        name_reading_en: "name"
        email: "example@example.com"
        icon_uri {
          uri; null
          thumb: {
            uri: null
          }
        }
        department: "部署"
        active: true
        slack: "slack"
      }
    }
  @apiUse NotFound
  @apiUse UnprocessableEntity
=end
  def gc_auth
    if params[:gc_switch]
      begin
        auth_uri = SettingGc.gc_auth(@emp_google.auth_hash, @emp_google.calendar_id)
        render json: {auth_uri: auth_uri}
      rescue => e
        logger.info(e)
        ErrorSlackNotifier.delay.error_occured(current_api_employee.company, e, e.message)
        return
      end
    else
      @emp_google.update_attributes!(auth_init)
      render_success_msg(I18n.t('.controllers.employees.gc_auth.gc_remove'))
    end
  end

  def gc_auth_with_code
    if !@emp_google.integrated? && @emp_google.expired?
      auth_info = SettingGc.gc_auth_with_code(params[:code])
      if auth_info
        @emp_google.update_attributes!(auth_hash: auth_info, expiry_date: Time.current.since(2.month))
        render_success_msg(I18n.t('.controllers.employees.gc_auth.gc_integration'))
      else
        render_error('E04020', 'integration_failure', 400)
      end
    end
  end

  def gc_info
    if @emp_google.integrated? && !@emp_google.expired?
      SettingGc.delay.check_calendar(@emp_google.auth_hash)
      calendar_ids = SettingGc.get_calendar_lists(@emp_google.auth_hash)
      render json: {gc_info: {auth_flag: true, calendar_ids: calendar_ids, calendar_id: @emp_google.calendar_id}}, status: 200
    elsif @emp_google.integrated? && @emp_google.expired?
      @emp_google.update_attributes!(auth_init)
      render json: {gc_info: {auth_flag: false}}, status: 200
    else
      render json: {gc_info: {auth_flag: false}}, status: 200
    end
  end


=begin
  @api {put} /api/employee/registration EmployeeRegistraion
  @apiName EmployeeRegistration
  @apiGroup Employee
  @apiDescription 社員本登録
  @apiPermission general


  @apiParam {Object} employee
  @apiParam {String} employee.password パスワード
  @apiParam {String} [employee.name] 管理者名
  @apiParam {String} [employee.slack] Slack名

  @apiSuccess {Object} employee
  @apiSuccess {String} employee.uqid 社員ID
  @apiSuccess {String} employee.email メール
  @apiSuccess {String} employee.name 名前
  @apiSuccess {String} employee.slack slack名
  @apiSuccess {String} company.active 登録状況
  @apiSuccessExample Success-Response:
    HTTP/1.1 201 OK
    {
      employee: {
        uqid: "123456"
        email: "host@example.com"
        uid: "host@example.com"
        name: "name"
        name_reading: "name"
        first_name: "first_name"
        last_name: "last_name"
        name_reading_en: "name"
        email: "example@example.com"
        icon_uri {
          uri; null
          thumb: {
            uri: null
          }
        }
        department: "部署"
        active: true
        slack: "slack"
      }
    }
  @apiUse NotFound
  @apiUse UnprocessableEntity
=end
  def registration
    current_api_employee.update_attributes!(registration_params)
    EmployeeMailer.registration(current_api_employee).deliver_later
    render json: current_api_employee, status: 201
  end

=begin
  @api {put} /api/employee/check_admin_domain ValidateDomain
  @apiName ValidateDomain
  @apiGroup Auth
  @apiDescription 企業管理者の重複ドメインチェック
  @apiPermission general

  @apiParam {String} [email] 入力されたメールアドレス

  @apiSuccessExample Success-Response:
    HTTP/1.1 201 OK
    {}
  @apiUse NotFound
=end
  def check_admin_domain
    email_param_domain = get_domain(params[:email])
    unless FreeAddress::DOMAINS.include?(email_param_domain)
      admin_employees = Employee.where(admin: true)
      domains = []
      admin_employees.map { |admin_employee| domains << admin_employee.get_admin_domain }
      if domains.include?(email_param_domain)
        render json: {message: I18n.t(".controllers.employees.check_admin_domain.already_used_domain")}
      end
    end
  end

  private

  def update_params
    params.require(:employee).
      permit(
      :password,
      :name,
      :name_reading,
      :first_name,
      :last_name,
      :department,
      :icon_uri,
      :email,
      :slack,
      :cw_id,
      :one_team,
      :facebook_workplace,
      :slack_sub,
      :cw_id_sub,
      :one_team_sub,
      :line_works,
      :line_works_sub,
      :facebook_workplace_sub,
      :dingtalk,
      :dingtalk_sub,
      :ms_teams,
      :ms_teams_sub
    )
  end
  def registration_params
    params.require(:employee).
      permit(
        :password,
        :name,
        :name_reading,
        :first_name,
        :last_name,
        :department,
        :slack,
        :cw_id,
        :one_team,
        :line_works,
        :facebook_workplace,
        :dingtalk,
        :ms_teams
    )
  end

  def auth_init
    {auth_hash: nil, calendar_id: nil, expiry_date: nil}
  end

  def render_success(obj)
    render json: obj, staus: 200
  end

  def render_failure(msg)
    render json: {message: msg}, status: 422
  end

  def render_error(code, locale, status)
    render json: {
      error: {
        code: code,
        message: I18n.t(".controllers.employees." + locale)
      }
    }, status: status
  end

  def render_success_msg(msg)
    render json: {message: msg}, status: 200
  end

  def build_emp_google
    unless current_api_employee.employee_google
      EmployeeGoogle.create!(employee_id: current_api_employee.id)
    end
    @emp_google = current_api_employee.employee_google
  end

  def check_emp_google
    unless current_api_employee.employee_google
      render json: {gc_info: {auth_flag: false}}, status: 200
    end
  end

  def get_domain(email)
    email =~ /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i
    $2
  end

  def cache_key(ops=nil)
    [
      @company.id,
      "employees##{action_name}",
      ops
    ].join('/')
  end

  def delete_emp_list_cache
    current_api_employee.delete_emp_list_cache
  end
end
