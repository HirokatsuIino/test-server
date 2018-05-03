class Api::CompaniesController < ApplicationController
  # before_action :authenticate_api_employee!, except: :admin_authorize unless Rails.env.development?
  before_action :login_employee_only!, except: :admin_authorize
  before_action :admin!, only: [:show, :update_employee, :destroy_employee, :create_or_update_card, :card_info, :download_template, :import_csv, :show_employee, :resend_confirmmation, :create, :update, :admin_confirm] unless Rails.env.development?
  before_action :prepare_company, only: [:home, :show, :export, :export_current_csv, :visitors_info, :update, :show_employee, :setting_apps, :settings, :active_chats, :update_employee, :resend_confirmation, :test_notifier, :change_plan, :update_tablet_plan, :downgrade_tablet_plan, :destroy_employee, :download_template, :import_csv, :import_override_csv, :override_csv_execute, :admin_confirm, :card_info]
  after_action :active!, only: :create
  before_action :check_plan_status, only: [:import_csv] unless Rails.env.development?
  before_action :check_appointments_finished, only: :destroy_employee
  before_action :set_visitor_data, only: :visitors_info
  before_action :restrict_employee_read, only: :visitors_info
  before_action :restrict_employee_download, only: :export

  WITH_CODE = '受付コード'
  WITHOUT_CODE = '担当者検索'
  PAYJP_CS_CHANNEL = Rails.env.production? ? "#receptionist-payjp".freeze : "#receptionist-payjp-t".freeze

=begin
  @api {get} /api/company/home  Home
  @apiName Home
  @apiGroup Company
  @apiDescription 管理者画面のTOPPAGEの取得
  @apiPermission admin

  @apiSuccess {Object} company
  @apiSuccess {String} company.name 会社名
  @apiSuccess {String} company.zipcode 郵便番号
  @apiSuccess {String} company.address1 都道府県市町村区
  @apiSuccess {String} company.address2 番地 建物名
  @apiSuccess {String} company.phone_no 電話番号
  @apiSuccess {Integer} company.employees_count 社員数
  @apiSuccess {Integer} company.visitors_count visitor数
  @apiSuccess {String} company.plan_status プラン
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {
      "company": {
        "name": "example"
        "zipcode": "111-1111"
        "address1": "都道府県市町村区"
        "address2": "番地 建物名"
        "phone_no": "090-0980-0980"
        "employees_count": 14
        "visitors_count": 27
        "plan_status": "trial"
        "available_count": 2
      }
    }

  @apiUse Unauthorized
=end
  def home
    render json: @company, serializer: HomeSerializer
  end

=begin
  @api {get} /api/company/settings IndexSettings
  @apiName IndexSettings
  @apiGroup Company
  @apiDescription 受付アプリ・カスタムボタン設定情報の取得
  @apiPermission admin

  @apiSuccess {Object} company.setting_apps
  @apiSuccess {String} company.setting_apps.uid uid
  @apiSuccess {String} company.setting_apps.tablet_location 使用中のtabletの名前
  @apiSuccess {String} company.setting_apps.theme テーマ ('Light' or 'Dark')
  @apiSuccess {String} company.setting_apps.logo_url ロゴ画像
  @apiSuccess {String} company.setting_apps.bg_url 背景画像
  @apiSuccess {String} company.setting_apps.bg_rgb 背景RGB
  @apiSuccess {Integer} company.setting_apps.bg_default デフォルト背景画像 (1~6)
  @apiSuccess {String} company.setting_apps.text ロゴテキスト
  @apiSuccess {String} company.setting_apps.text_en ロゴテキスト(英語)
  @apiSuccess {String} company.setting_apps.done_text 完了テキスト
  @apiSuccess {String} company.setting_apps.done_text_en 完了テキスト(英語)
  @apiSuccess {Boolean} company.setting_apps.code 受付コードボタンの表示・非表示
  @apiSuccess {Boolean} company.setting_apps.search 社員検索ボタンの表示・非表示
  @apiSuccess {Boolean} company.setting_apps.input_name 名前入力ON/OFF
  @apiSuccess {Boolean} company.setting_apps.input_company 社名入力ON/OFF
  @apiSuccess {Boolean} company.setting_apps.input_number 人数入力ON/OFF
  @apiSuccess {string} company.setting_apps.tel_error 通知エラー時の連絡先
  @apiSuccess {Object} company.setting_customs
  @apiSuccess {String} company.setting_customs.uid uid
  @apiSuccess {Boolean} company.setting_customs.active 有効無効
  @apiSuccess {Boolean} company.setting_customs.recording 来訪者記録表示・非表示
  @apiSuccess {Boolean} company.setting_customs.input_name 名前入力ON/OFF
  @apiSuccess {Boolean} company.setting_customs.input_company 社名入力ON/OFF
  @apiSuccess {String} company.setting_customs.text 表示テキスト
  @apiSuccess {String} company.setting_customs.text_en 表示テキスト(英語)
  @apiSuccess {String} company.setting_customs.mention_in 通知場所
  @apiSuccess {String} company.setting_customs.mention_to 通知相手
  @apiSuccess {Integer} company.setting_customs.cw_account_id chatworkのアカウントID
  @apiSuccess {Object} company.setting_customs.chat
  @apiSuccess {String} company.setting_customs.chat.uid uid
  @apiSuccess {String} company.setting_customs.chat.name チャットの名前

  @apiSuccessExample Success-Response:
  HTTP/1.1 200 OK
    {
      "company": {
        setting_apps: [
            {
              uid: "bla-bla-bla",
              tablet_location: "tablet 1",
              theme: 'Light',
              logo_url: {
               logo_url: {
                 url: "https://receptionist/bg_url",
                 thumb: "https://receptionist/bg_url_thumb"
               }
              },
              bg_url: {
               bg_url: {
                 url: "https://receptionist/bg_url",
                 thumb: "https://receptionist/bg_url_thumb"
               }
              },
              bg_rgb: "ffffff",
              bg_default: 1,
              text: "ロゴテキスト",
              text_en: "ロゴテキスト(英語)",
              done_text: "完了しました",
              done_text_en: "done text",
              code: true,
              search: true,
              input_name: true,
              input_company: true,
              input_number: true,
              tel_error: '03-xxxx-xxxx'
            },
            {
              uid: "bla-bla-bla",
              tablet_location: "tablet 2",
              theme: 'Dark',
              logo_url: {
               logo_url: {
                 url: "https://receptionist/bg_url",
                 thumb: "https://receptionist/bg_url_thumb"
               }
              },
              bg_url: {
               bg_url: {
                 url: "https://receptionist/bg_url",
                 thumb: "https://receptionist/bg_url_thumb"
               }
              },
              bg_rgb: "ffffff",
              bg_default: 1,
              text: "ロゴテキスト",
              text_en: "ロゴテキスト(英語)",
              done_text: "完了しました",
              done_text_en: "done text",
              code: true,
              search: true,
              input_name: true,
              input_company: true,
              input_number: true,
              tel_error: '03-xxxx-xxxx'
            }
          ],

          setting_customs: [
            {
              uid: "bla-bla-bla",
              active: true,
              recording: true,
              input_name: true,
              input_company: true,
              input_number: true,
              text: "宅配便はこちら",
              mention_to: "@someone",
              mention_in: "general",
              cw_account_id: "null",
              chat: {
                uid: "bla-bla-bla",
                name: "Slack"
              }
            },
            {
              uid: "bla-bla-bla",
              active: true,
              recording: true,
              input_name: true,
              input_company: true,
              input_number: true,
              text: "宅配便はこちら",
              mention_in: "123456"
              mention_to: "someone",
              cw_account_id: "null",
              chat: {
                uid: "bla-bla-bla",
                name: "Chatwork"
              }
            }
        ]
      }
    }

  @apiUse Unauthorized
=end
  def settings
    render json: @company, serializer: SettingsSerializer
  end

=begin
  @api {get} /api/company ShowCompany
  @apiName ShowCompany
  @apiGroup Company
  @apiDescription 会社情報の取得
  @apiPermission admin

  @apiSuccess {Object} company
  @apiSuccess {String} company.uid 会社UID
  @apiSuccess {String} company.name 会社名
  @apiSuccess {String} company.name_reading_en 会社読み仮名英語
  @apiSuccess {String} company.zipcode 郵便番号
  @apiSuccess {String} company.address1 都道府県市町村区
  @apiSuccess {String} company.address2 番地 建物名
  @apiSuccess {String} company.phone_no 電話番号
  @apiSuccess {Integer} company.count 社員数
  @apiSuccess {String} company.admin_name 代表者名
  @apiSuccess {String} company.corporate_url HP
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {
      company: {
        uid: "uid",
        name: "company name",
        name_reading_en: "company english name",
        zip_zode: "郵便番号",
        address1: "都道府県市町村区",
        address2: "番地 建物名",
        phone_no: "電話番号",
        plan_status: "スタンダード"
        count: 10
        admin_name: "admin_name"
        corporate_url: "http://example.com"
      }
    }

  @apiUse Unauthorized
  @apiUse NotFound
=end
  def show
    render json: @company, status: 200
  end

=begin
  @api {put} /api/company/update_employee UpdateEmployeeByAdmin
  @apiName UpdateEmployeeByAdmin
  @apiGroup Employee
  @apiDescription 管理者による社員情報の更新
  @apiPermission general

  @apiParam {Object} employee
  @apiParam {String} [employee.email] メールアドレス
  @apiParam {String} [employee.name] 管理者名
  @apiParam {String} [employee.name_reading] 読み仮名
  @apiParam {String} [employee.name_reading_en] 読み仮名英語
  @apiParam {String} [employee.password] パスワード
  @apiParam {String} [employee.slack] Slack名
  @apiParam {String} [employee.icon_url] アイコン画像
  @apiParam {String[]} mentions 社員別通知先チャネル (エンタープライズのみ)
  @apiParam {String} mentions.chat_id チャットID
  @apiParam {String} mentions.mention_id 通知先チャネル

  @apiSuccess {Object} employee
  @apiSuccess {String} employee.uqid 社員ID
  @apiSuccess {String} employee.email メール
  @apiSuccess {String} employee.name 名前
  @apiSuccess {String} employee.slack slack名
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
  def update_employee
    employee = @company.employees.find_by(uqid: params[:employee_uqid])
    if employee.should_get_slack_user_id?(employee_update_params)
      render_error('E04011', 'slack_user_id_not_found', 422) and return unless employee.update_slack_user_id(@company.setting_chat_slack.token, employee_update_params[:slack])
    end
    if employee.should_get_slack_user_id_sub?(employee_update_params)
      render_error('E04011', 'slack_user_id_sub_not_found', 422) and return unless employee.update_slack_user_id_sub(@company.setting_chat_slack.token, employee_update_params[:slack_sub])
    end
    cw_mention_in = params[:mentions].present? ? params[:mentions].find{|m| m[:chat][:id].to_i == 2} : nil
    sc = @company.get_setting_chat('Chatwork')
    cw_update_type = sc.get_cw_update_type(employee, cw_mention_in, employee_update_params) # determine if cw related columns should be updated
    if cw_update_type
      if employee_update_params[:cw_id] && sc.mention_in && sc.token
        # get chatwork id and account
        attributes = sc.update_cw_ids(cw_update_type, cw_mention_in, employee_update_params)
        if attributes
          employee.update_attributes!(attributes) # update if no fail calling chatwork api
          employee.delete_emp_list_cache
          employee.update_mentions(params[:mentions]) if @company.upgraded_plan?
          render_success(employee)
        else
          render_error('E03000', 'cw_account_not_found', 422)
        end
      else
        render_error('E03001', 'cw_info_not_found', 422)
      end
    else
      employee.update_attributes!(employee_update_params)
      employee.delete_emp_list_cache
      # issue#1009
      employee.update_mentions(params[:mentions]) if @company.upgraded_plan?
      render_success(employee)
    end
  end

=begin
  @api {put} /api/company/admin_confirm UpdateEmployeeToAdminConfirmation
  @apiName UpdateEmployeeToAdminConfirmation
  @apiGroup Employee
  @apiDescription 管理者権限付与のメール認証
  @apiPermission general

  @apiParam {Object} employee
  @apiParam {String} [employee.uqid] 社員uid

  @apiSuccess {Object} employee
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {}
  @apiUse NotFound
=end
  def admin_confirm
    if @company.upgraded_plan?
      if @company.can_add_admin?
        target_employee = @company.employees.find_by(uqid: employee_admin_params[:uqid])
        if target_employee && !target_employee.admin
          if !target_employee.admin_authority_sent_at
            token = SecureRandom.urlsafe_base64(nil, false)
            target_employee.update_attributes(
              admin_authority_token: token,
              admin_authority_sent_at: Time.now
            )

            url = Constants::WEB_ROOT
            admin_authority_url = url + '/admin_authorize' + '?admin_authority_token=' + token + '&employee_uqid=' + target_employee.uqid
            AdminMailer.admin_confirm(target_employee, admin_authority_url).deliver_later
            render_success(target_employee)
          else
            # 既に確認メールを送っている
            render_error('E03053', 'admin_confirm_already_sent', 422)
          end
        else
          # adminにしようとしている社員が存在しない
          # もしくはすでにadmin
          render_error('E03052', 'cannot_update_admin_flag', 422)
        end
      else
        # 規定人数いっぱい
        render_error('E03051', 'limit_admin_num_to_admin', 422)
      end
    else
      render_error('E03050', 'enterprise_only', 403)
    end
  end

=begin
  @api {get} /api/company/admin_authorize UpdateEmployeeToAdminAuthorization
  @apiName UpdateEmployeeToAdminAuthorization
  @apiGroup Employee
  @apiDescription 社員への管理者権限の付与
  @apiPermission general

  @apiSuccess {Object} employee
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {}
  @apiUse NotFound
=end
  def admin_authorize
    path = '/'
    url = Constants::WEB_ROOT + path

    if params[:admin_authority_token] && params[:employee_uqid]
      if current_api_employee
        if current_api_employee.uqid == params[:employee_uqid]
          if current_api_employee.company.can_add_admin?
            if params[:admin_authority_token] == current_api_employee.admin_authority_token
              current_api_employee.update_attributes(
                admin: true,
                admin_authorized_at: Time.now
              )
              render json: {}, status: 200
            else
              # tokenが一致しない
              render json: {redirect_url: url}, status: 422
            end
          else
            render json: {
                redirect_url: url,
                error: {
                  code: 'E03051',
                  message: I18n.t(".controllers.companies.limit_admin_num_to_employee")
                }
              }, status: 422
          end
        else
          # ログインしているユーザーと管理者にするユーザーが異なる
          render json: {redirect_url: url}, status: 422
        end
      else
        # ログインしていないため、/sign_inリダイレクト
        # redirect paramを付け、ログイン後にまたapiを叩くようにする
        redirect = Constants::WEB_ROOT
        admin_authority_url = redirect + '/admin_authorize' + '?admin_authority_token=' + params[:admin_authority_token] + '&employee_uqid=' + params[:employee_uqid]
        render json: {redirect_url: url+'sign_in?redirect='+CGI.escape(admin_authority_url)}, status: 422
      end
    else
      # admin_authority_tokenがない
      render json: {redirect_url: url}, status: 422
    end
  end

=begin
  @api {put} /api/company/admin_deprive UpdateEmployeeAdminToNormalEmployee
  @apiName UpdateEmployeeToAdminAuthorization
  @apiGroup Employee
  @apiDescription 管理者を一般社員に変更
  @apiPermission general

  @apiSuccess {Object} employee
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {}
  @apiUse NotFound
=end
  def admin_deprive
    target_employee = Employee.find_by(uqid: employee_admin_params[:uqid])
    if target_employee
      if target_employee.admin
        target_employee.update(admin: false)
      else
        # 対象社員adminじゃない
        render_error('E03', '', 422)
      end
    else
      # 対象社員が存在しない
      render_error('E03', '', 422)
    end
  end

=begin
  @api {delete} /api/company/destroy_employee DeleteEmployee
  @apiName DeleteEmployee
  @apiGroup Company
  @apiDescription 社員削除
  @apiPermission admin


  @apiParam {String} employee_uqid 社員uqid
  @apiSuccessExample Success-Response:
    HTTP/1.1 201 OK
    {}

  @apiUse NotFound
  @apiUse UnprocessableEntity
=end
  def destroy_employee
    if @employee.destroyable?
      @employee.mention_ins.destroy_all # foreign keyが貼られているので先に削除する
      @employee.destroy!
      @employee.delete_emp_list_cache
      # ダウングレード対象かチェックする
      employee_count = @company.employees.count
      plan_changed = employee_count == 10 || employee_count % 50 == 0
      render json: {}, status: 200
    else
      render_error('E03002', 'disable_delete_host', 400)
    end
  end

=begin
  @api {get} /api/company/download_template DownloadCsvTemplate
  @apiName DownloadCsvTemplate
  @apiGroup Company
  @apiDescription CSVテンプレートのダウンロード
  @apiPermission admin

  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {}

  @apiUse NotFound
=end
  def download_template
    # TODO: companyの言語によってheaderの言語を切り替える
    if @company.for_line_works?
      header = ['名前', 'メールアドレス', '名前(カナ)', 'Firstname', 'Lastname', '部署', 'Slack ID', 'Slackのアシスタント用通知アカウント', 'Slackの通知先channel名', 'Chatwork ID', 'ChatWorkのアシスタント用ID', 'Chatwork アカウントID', 'ChatWorkのアシスタント用アカウントID', 'ChatWorkの通知先グループチャットURL', 'Oneteam ユーザーID', 'Oneteamのアシスタント用ユーザーID', 'Oneteam Webhook URL', 'Facebook Workplace ユーザーID', 'Facebook Workplace アシスタント用ユーザーID', 'Facebook Workplace グループID', 'LINE WORKS ユーザーID', 'LINE WORKS アシスタント用ユーザーID']
    elsif !@company.for_line_works? && @company.upgraded_plan?
      header = ['名前', 'メールアドレス', '名前(カナ)', 'Firstname', 'Lastname', '部署', 'Slack ID', 'Slackのアシスタント用通知アカウント', 'Slackの通知先channel名', 'Chatwork ID', 'ChatWorkのアシスタント用ID', 'Chatwork アカウントID', 'ChatWorkのアシスタント用アカウントID', 'ChatWorkの通知先グループチャットURL', 'Oneteam ユーザーID', 'Oneteamのアシスタント用ユーザーID', 'Oneteam Webhook URL', 'Facebook Workplace ユーザーID', 'Facebook Workplace アシスタント用ユーザーID', 'Facebook Workplace グループID']
    else
      header = ['名前', 'メールアドレス', '名前(カナ)', 'Firstname', 'Lastname', '部署', 'Slack ID', 'Chatwork ID', 'Chatwork アカウントID', 'Oneteam ユーザーID', 'Facebook Workplace ユーザーID']
    end
    csv_file = CSV.generate do |csv|
      csv << header
    end
    csv_file.encode!(Encoding::SJIS)

    send_data(csv_file, type: 'text/csv; charset=shift_jis', filename: "[RECEPTIONIST]社員一覧.csv")
  end

=begin
  @api {get} /api/company/export ExportVisitor
  @apiName ExportVisitor
  @apiGroup Company
  @apiDescription 来訪者の一覧のエクスポート
  @apiPermission admin

  @apiParam {date} from
  @apiParam {data} to
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {}

  @apiUse NotFound
=end
  def export
    if params[:from] && params[:to]
      from_date = Time.parse(params[:from]).beginning_of_day
      to_date = Time.parse(params[:to]).end_of_day
      visitors = @company.visitors.where(visited_at: from_date..to_date).order_by_desc
      render_error('E03031', 'no_visitors', 400) and return unless visitors.present?
      send_data(visitors.to_csv, type: 'text/csv; charset=shift_jis', filename: "visitors.csv")
    else
      render_error('E03030', 'datetime_range_not_found', 400)
    end
  end

=begin
  @api {get} /api/company/export_current_csv ExportCurrentCsv
  @apiName ExportCurrentCsv
  @apiGroup Company
  @apiDescription 現在の社員情報CSVファイルのダウンロード
  @apiPermission admin

  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {}

  @apiUse NotFound
=end
  def export_current_csv
    employees = @company.employees
    # header = ['Name','Email','NameReading','FirstName','LastName','Department','SlackId','ChatWorkId','ChatWorkAccountId']
    # columns = ['name', 'email', 'name_reading', 'first_name', 'last_name', 'department', 'slack', 'cw_id', 'cw_account_id']

    # bom = %w(EF BB BF).map { |e| e.hex.chr }.join # utf-8
    # bom = %w(FF FE).map { |e| e.hex.chr }.join # utf-16(LE)
    # data = CSV.generate(bom) do |csv|
    #   csv << header
    #   employees.each do |employee|
    #     csv << employee.attributes.values_at(*columns)
    #   end
    # end
    # bom = "\xFF\xFE".force_encoding("UTF-16LE")

    # send_data(
    #   bom + output.encode("UTF-16LE"),
    #   # data,
    #   :type => 'text/csv',
    #   :filename => "employees.csv"
    # )

    send_data(employees.to_csv(@company), type: 'text/csv; charset=shift_jis', filename: "[RECEPTIONIST]社員一覧.csv")
  end


=begin
  @api {post} /api/company/change_plan ChangePlan
  @apiName UpdateTabletPlan
  @apiGroup Company
  @apiDescription プランの変更
  @apiPermission admin

  @apiParam {String} plan_status 'standard' or 'enterprise'

  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {}

  @apiUse NotFound
=end
  def change_plan
    if @company.payjp_registered?
      if @company.measured_price?
        if params[:plan_status] == 'standard'
          result = @company.update(plan_status: 'standard')
          @company.reset_enterprise_features
          render json: @company, status: 200
        elsif params[:plan_status] == 'enterprise'
          if @company.employees.count > 10
            current_plan_id = @company.ec_plan_id
            @company.update(plan_status: 'enterprise')
            render json: @company, status: 200
          else
            render_error_without_locale('E', "エンタープライズプランは社員数が11名以上の企業様のみご利用可能です", 422)
          end
        end
      else
        @company.update(plan_status: params[:plan_status])
        render json: @company, status: 200
      end
    else
      render_error('E03041', 'card_registration_required', 400)
    end
  end


=begin
  @api {post} /api/company/update_tablet_plan UpdateTabletPlan
  @apiName UpdateTabletPlan
  @apiGroup Company
  @apiDescription タブレット台数の増加
  @apiPermission admin

  @apiParam {Object} tablet_plan

  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {}

  @apiUse NotFound
=end
  def update_tablet_plan
    if @company.payjp_registered?
      result = nil
      ActiveRecord::Base.transaction do
        result = @company.update_tablet_plan
      end

      if result.nil?
        notifier = Slack::Notifier.new(Rails.application.config.slack_webhook_url, channel: PAYJP_CS_CHANNEL)
        message = <<-EOS
<!here> タブレットが追加されました :iphone:
会社ID: #{@company.id}
会社名: #{@company.name}
salesforceID: #{@company.salesforce_id}
追加後タブレット台数: #{@company.setting_apps.count}
        EOS
        notifier.ping(message)
        render json: @company, status: 200
      else
        render_error_without_locale('E03012', result[:message], 422)
      end
    else
      render_error('E03013', 'card_registration_required', 400)
    end
  end

=begin
  @api {post} /api/company/downgrade_tablet_plan DowngradeTabletPlan
  @apiName DowngradeTabletPlan
  @apiGroup Company
  @apiDescription タブレット台数の引き下げ
  @apiPermission admin

  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {}

  @apiUse NotFound
=end
  def downgrade_tablet_plan
    if @company.payjp_registered?
      if @company.setting_apps.count > 1
        @company.setting_apps.last.destroy!
        notifier = Slack::Notifier.new(Rails.application.config.slack_webhook_url, channel: PAYJP_CS_CHANNEL)
        message = <<-EOS
<!here> タブレットが削除されました :iphone:
会社ID: #{@company.id}
会社名: #{@company.name}
salesforceID: #{@company.salesforce_id}
削除後タブレット台数: #{@company.setting_apps.count}
        EOS
        notifier.ping(message)
        render json: @company, status: 200
      else
        render_error_without_locale('E03040', "使用中のタブレットが1台しかありません", 422)
      end
    else
      render_error('E03041', 'card_registration_required', 400)
    end
  end


=begin
  @api {post} /api/company/create_or_update_card CreateOrUpdateCard
  @apiName CreateOrUpdateCard
  @apiGroup Company
  @apiDescription クレジットカード情報の登録・更新
  @apiPermission admin

  @apiParam {Integer} [number]
  @apiParam {Integer} [cvc]
  @apiParam {Integer} [exp_month]
  @apiParam {Integer} [exp_year]

  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {}

  @apiUse UnprocessableEntity
=end
  def create_or_update_card
    if !current_api_employee.company.payjp_registered?
      # not registered
      # create card token
      card = Company.create_card_token(
        params[:number],
        params[:cvc],
        params[:exp_month],
        params[:exp_year]
      )

      # create customer for pay.jp
      new_card = current_api_employee.company.create_customer_and_card(
        current_api_employee.email,
        card.id
      )
      if new_card
        render_success({message: I18n.t(".controllers.companies.create_success")})
      else
        render_error('E03010', 'cannot_create_card', 400)
      end
    else
      # already registered
      status = current_api_employee.company.update_card(
        params[:number],
        params[:cvc],
        params[:exp_month],
        params[:exp_year]
      )
      if status
        render_success({message: I18n.t(".controllers.companies.update_success")})
      else
        render_error('E03011', 'cannot_update_card', 400)
      end
    end
  rescue => e
    render_error('E03014', 'cannot_update_card', 400)
  end

=begin
  @api {post} /api/company/card_info ShowCard
  @apiName ShowCard
  @apiGroup Company
  @apiDescription クレジットカード情報の取得
  @apiPermission admin

  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {}

  @apiUse Unauthorized
=end
  def card_info
    response = { is_registered: false }
    render_success(response) and return unless @company.payjp_registered?
    if card = @company.current_card
      response[:is_registered] = true
      render_success(response.merge(card: card))
    else
      render_success(response)
    end
  end

=begin
  @api {post} /api/company/import_csv CreateEmployeeByCsv
  @apiName CreateEmployeeByCsv
  @apiGroup Company
  @apiDescription 社員をCSVファイルで登録する
  @apiPermission admin

  @apiParam {Object} employee
  @apiParam {String} employee.email メールアドレス
  @apiParam {String} [employee.name] 名前
  @apiParam {String} [employee.name_reading] 読み仮名
  @apiParam {String} [employee.first_name] FirstName
  @apiParam {String} [employee.last_name] LastName
  @apiParam {String} [employee.slack] Slack ID
  @apiParam {String} [employee.cw_id] Chatwork ID
  @apiParam {String} [employee.department] 部署名
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {}

  @apiUse NotFound
  @apiUse UnprocessableEntity
  @apiUse Unauthorized
=end

  def import_csv
    if params[:csv_file].blank? || File.extname(params[:csv_file].original_filename) != ".csv"
      render_error('E03005', 'cannot_load_csv', 422)
    else
      @company.update(csv_file: params[:csv_file])
      status = Employee.validate_csv(params[:csv_file], current_api_employee)
    end
    if status
      render json: { error: { code: 'E03006', message: status[:msg] } }, status: 400
    else
      render json: {}, status: 200
    end
  end

=begin
  @api {post} /api/company/import_override_csv PreviewEmployeeByOverrideCsv
  @apiName PreviewEmployeeByOverrideCsv
  @apiGroup Company
  @apiDescription 上書きCSVアップデートしてプレビュー結果を返す
  @apiPermission admin

  @apiParam {Object} employee
  @apiParam {String} employee.email メールアドレス
  @apiParam {String} [employee.name] 管理者名
  @apiParam {String} [employee.name_reading] 読み仮名
  @apiParam {String} [employee.first_name] FirstName
  @apiParam {String} [employee.last_name] LastName
  @apiParam {String} [employee.slack] Slack ID
  @apiParam {String} [employee.cw_id] Chatwork ID
  @apiParam {String} [employee.department] 部署名
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {}

  @apiUse NotFound
  @apiUse UnprocessableEntity
  @apiUse Unauthorized
=end

  def import_override_csv
    if params[:csv_file].blank? || File.extname(params[:csv_file].original_filename) != ".csv"
      render_error('E03005', 'cannot_load_csv', 422)
    else
      @company.update(csv_file: params[:csv_file])
      result = Employee.overrided_csv_info(params[:csv_file], current_api_employee)
    end
    if result[:msg]
      render json: { error: { code: 'E03006', message: result[:msg] } }, status: 400
    else
      render json: { result: result }, status: 200
    end
  end

=begin
  @api {post} /api/company/override_csv_execute CreateEmployeeByOverrideCsv
  @apiName CreateEmployeeByOverrideCsv
  @apiGroup Company
  @apiDescription 上書きCSVアップデートして新規作成・更新・削除を一括で行う
  @apiPermission admin

  @apiParam {Object} employee
  @apiParam {String} employee.email メールアドレス
  @apiParam {String} [employee.name] 管理者名
  @apiParam {String} [employee.name_reading] 読み仮名
  @apiParam {String} [employee.first_name] FirstName
  @apiParam {String} [employee.last_name] LastName
  @apiParam {String} [employee.slack] Slack ID
  @apiParam {String} [employee.cw_id] Chatwork ID
  @apiParam {String} [employee.department] 部署名
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {}

  @apiUse NotFound
  @apiUse UnprocessableEntity
  @apiUse Unauthorized
=end
  def override_csv_execute
    result = Employee.override_csv(params[:csv_file], current_api_employee)
    render json: { result: result }, status: 200
  end

=begin
  @api {get} /api/company/visitors_info IndexVisitors
  @apiName IndexVisitors
  @apiGroup Company
  @apiDescription 来訪者の一覧
  @apiPermission admin

  @apiSuccess {Object} visitor
  @apiSuccess {Integer} visitor.id 来訪者ID
  @apiSuccess {String} visitor.name 名前
  @apiSuccess {String} visitor.company_name 会社名
  @apiSuccess {String} visitor.number 訪問人数
  @apiSuccess {Integer} visitor.visited_at 来訪日時
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK

    {
      "id": 1,
      "name": "name1",
      "email": "example1@gmail.com",
      "company_name": "company_name",
      "number": 1,
      "visited_at": 20160101
    }

  @apiUse NotFound
=end
  def visitors_info
    if params[:chart]
      render json: { data: @data }, status: 200
    elsif params[:page]
      visitors = Kaminari.paginate_array(@visitors).page(params[:page].to_i).per(20)
      render json: visitors, meta: { total_pages: visitors.total_pages, current_page: visitors.current_page, employee_visitor_download: @company.employee_visitor_download, employee_visitor_read: @company.employee_visitor_read }, status: 200
    else
      render json: @visitors, status: 200
    end
  end

=begin
  @api {get} /api/company/show_employee ShowEmployee
  @apiName ShowEmployee
  @apiGroup Company
  @apiDescription 社員情報の取得
  @apiPermission admin

  @apiParam {Integer} employee_uqid

  @apiSuccess {Object} employee
  @apiSuccess {String} employee.uqid 社員ID
  @apiSuccess {String} employee.email メール
  @apiSuccess {String} employee.name 名前
  @apiSuccess {String} employee.name_reading カナ
  @apiSuccess {String} employee.first_name FirstName
  @apiSuccess {String} employee.last_name LastName
  @apiSuccess {String} employee.icon_uri プロフィール画像
  @apiSuccess {String} employee.department 部署
  @apiSuccess {String} employee.slack slack名
  @apiSuccess {String} company.active 登録状況
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {
      employee: {
        uqid: "1234556"
        email: "host@example.com"
        uid: "host@example.com"
        name: "name"
        name_reading: "name"
        first_name: "first_name"
        last_name: "last_name"
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
  def show_employee
    @employee = @company.employees.find_by(uqid: params[:employee_uqid])
    render json: @employee, status: 200
  end

=begin
  @api {post} /api/company/resend_confirmation ResendConfirmationMail
  @apiName ResendConfirmationMail
  @apiGroup Company
  @apiDescription 本登録メールの再送
  @apiPermission admin


  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {}

  @apiUse NotFound
=end
  def resend_confirmation
    resources = @company.employees.notification_unavailable
    render_error('E03003', 'unactive_employees_not_found', 404) unless resources

    path = '/api/auth/confirmation?'
    confirmation_root_path = Constants::API_ROOT + path

    resources.each do |resource|
      @resource = resource
      password = Devise.friendly_token[0,10]
      @resource.update(password: password)

      # give redirect value from params priority
      @redirect_url = params[:confirm_success_url]

      # fall back to default value if provided
      @redirect_url ||= DeviseTokenAuth.default_confirm_success_url

      custom_confirmation_url = confirmation_root_path + 'confirmation_token=' + @resource.confirmation_token
      @resource.delay.send_confirmation_instructions({
        client_config: params[:config_name],
        redirect_url: @redirect_url,
        custom_confirmation_url: custom_confirmation_url.html_safe,
        type: 'resend',
        employee_email: @resource.email,
        employee_name: @resource.name,
        temp_password: password
      })
    end
  end

=begin
  @api {post} /api/company CreateCompany
  @apiName CreateCompany
  @apiGroup Company
  @apiDescription ホスト企業管理者本登録(会社の情報の作成)
  @apiPermission admin

  @apiParam {Object} company
  @apiParam {String} company.name 会社名
  @apiParam {String} company.name_reading_en 会社名英語
  @apiParam {String} company.admin_name 管理者名
  @apiParam {String} company.zipcode 郵便番号
  @apiParam {String} company.address1 都道府県市町村区
  @apiParam {String} company.address2 番地 建物名
  @apiParam {String} company.phone_no 電話番号
  @apiParam {String} company.corporate_url 会社HP
  @apiParam {Object} employee
  @apiParam {String} employee.name 管理者名
  @apiParam {String} employee.name_reading 読み仮名
  @apiParam {String} employee.first_name FirstName
  @apiParam {String} employee.last_name LastName
  @apiParam {String} employee.password パスワード
  @apiParam {String} employee.slack Slack ID
  @apiParam {String} employee.cw_id Chatwork ID


  @apiSuccess {Object} company
  @apiSuccess {String} company.uid 会社UID
  @apiSuccess {String} company.name 会社名
  @apiSuccess {String} company.name_reading_en 会社読み仮名英語
  @apiSuccess {String} company.zipcode 郵便番号
  @apiSuccess {String} company.address1 都道府県市町村区
  @apiSuccess {String} company.address2 番地 建物名
  @apiSuccess {String} company.phone_no 電話番号
  @apiSuccess {Integer} company.count 社員数
  @apiSuccess {String} company.admin_name 代表者名
  @apiSuccess {String} company.corporate_url HP
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {
      company: {
        uid: "uid",
        name: "company name",
        name_reading_en: "company english name",
        zip_zode: "郵便番号",
        address1: "都道府県市町村区",
        address2: "番地 建物名",
        phone_no: "電話番号",
        plan_status: "スタンダード"
        count: 10
        admin_name: "admin_name"
        corporate_url: "http://example.com"
      }
    }

  @apiUse Unauthorized
  @apiUse UnprocessableEntity

=end
  def create
    @company = Company.new(company_params)

    #TODO インスタンスが作成される
    Company.transaction do
      @company.save!
      current_api_employee.update_attributes!(
        company_id: @company.id,
        admin: true,
        name: employee_params[:name],
        name_reading: employee_params[:name_reading],
        first_name: employee_params[:first_name],
        last_name: employee_params[:last_name],
        slack: employee_params[:slack],
        cw_id: employee_params[:cw_id],
        one_team: employee_params[:one_team],
        ms_teams: employee_params[:ms_teams],
        line_works: employee_params[:line_works],
        facebook_workplace: employee_params[:facebook_workplace],
        dingtalk: employee_params[:dingtalk]
      )
    end

    office = Office.new(
      name: @company.try(:name),
      time_zone: "Asia/Tokyo",
      zipcode: @company.try(:zipcode),
      language: 'ja',
      company_id: @company.try(:id)
    )
    office.save!

    # chats = Chat.all
    chats = Chat.first(4)
    chats.each do |chat|
      setting_chat = SettingChat.new(
        company_id: @company.try(:id),
        chat_id: chat.id,
        active: false,
        primary: 0,
        msg: 'お迎えに行く時は「OK」と言ってから行きましょう。',
        msg_en: 'Please say “OK” in this chat room if you are the person who will pick up the guest.'
      )
      setting_chat.save!
    end
    # LINE WOKRS
    SettingChat.create(
      company_id: @company.try(:id),
      chat_id: 6,
      active: false,
      primary: 0,
      msg: 'お迎えに行く時は「OK」と言ってから行きましょう。',
      msg_en: 'Please say “OK” in this chat room if you are the person who will pick up the guest.'
    )
    # MS Teams
    SettingChat.create(
      company_id: @company.try(:id),
      chat_id: 5,
      active: false,
      primary: 0,
      msg: 'お迎えに行く時は「OK」と言ってから行きましょう。',
      msg_en: 'Please say “OK” in this chat room if you are the person who will pick up the guest.'
    )

    setting_app = SettingApp.new(
      company_id: @company.try(:id),
      tablet_location: '本社受付',
      text: @company.try(:name),
      theme: 'Light',
      bg_rgb: 'ffffff',
      bg_default: 0,
      done_text: '担当がお迎えに上がりますので、少々お待ちくださいませ',
      done_text_en: 'Please wait...',
      code: 1,
      search: 1,
      input_name: true,
      input_company: true,
      input_number_code: true,
      input_number_search: true,
      monitoring: true,
      monitor_begin_at: Time.parse("0:00:00"),
      monitor_end_at: Time.parse("11:00:00"),
      tel_error: @company.try(:phone_no)
    )
    setting_app.save!

    actives = [true, false, true, true]
    button_types = [0, 1, 0, 0]
    recordings = [true, true, true, true]
    input_names = [true, true, true, false]
    input_companies = [false, true, true, false]
    input_numbers = [false, true, true, false]
    texts = ['面接の方はこちら', 'メッセージ用', '総合受付', '配達業者さま専用']
    texts_en = ['Employment interview', 'No Appointment', 'All other queries(general reception)', 'For courier']
    board_msgs = [nil, '大変申し訳ございませんが、お約束の無い方をおつなぎすることはできません。事前に弊社担当者とアポイントメントのお約束をお願い致します。', nil, nil ]
    board_msgs_en = [nil, 'I’m sorry, but we cannot connect you to anybody unless you have already made an appointment or he or she is already acquainted with you.', nil, nil]
    1.upto(4) do |n|
      setting_custom = SettingCustom.new(
        setting_app_id: setting_app.id,
        chat_id: params[:chat_id],
        active: actives[n-1],
        recording: recordings[n-1],
        input_name: input_names[n-1],
        input_company: input_companies[n-1],
        input_number: input_numbers[n-1],
        text: texts[n-1],
        text_en: texts_en[n-1],
        button_type: button_types[n-1],
        board_msg: board_msgs[n-1],
        board_msg_en: board_msgs_en[n-1]
      )
      setting_custom.save!
    end

    setting_gc = SettingGc.new(
      company_id: @company.try(:id),
      gc_id: 0
    )
    setting_gc.save!

    CompanySlackNotifier.delay.company_created(current_api_employee, @company) if Rails.env.production?
    EmployeeMailer.create_company(current_api_employee, @company).deliver_later
    render json: current_api_employee.as_json.merge(company: current_api_employee.company), status: 201
  end


=begin
  @api {put} /api/company UpdateCompany
  @apiName UpdateCompany
  @apiGroup Company
  @apiDescription 会社情報の更新
  @apiPermission admin

  @apiParam {Object} company
  @apiParam {String} [company.name] 会社名
  @apiParam {String} [company.name_reading] 会社名仮名
  @apiParam {String} [company.name_reading_en] 会社名英語
  @apiParam {String} [company.admin_name] 郵便番号
  @apiParam {String} [company.corporate_url] 郵便番号
  @apiParam {String} [company.zipcode] 郵便番号
  @apiParam {String} [company.address1] 都道府県市町村区
  @apiParam {String} [company.address2] 番地 建物名
  @apiParam {String} [company.phone_no] 電話番号
  @apiParam {String} [company.logo_url] ロゴ画像
  @apiParam {String} [company.bg_url] BG画像

  @apiSuccess {Object} company
  @apiSuccess {String} company.uid 会社UID
  @apiSuccess {String} company.name 会社名
  @apiSuccess {String} company.name_reading_en 会社読み仮名英語
  @apiSuccess {String} company.zipcode 郵便番号
  @apiSuccess {String} company.address1 都道府県市町村区
  @apiSuccess {String} company.address2 番地 建物名
  @apiSuccess {String} company.phone_no 電話番号
  @apiSuccess {Integer} company.count 社員数
  @apiSuccess {String} company.admin_name 代表者名
  @apiSuccess {String} company.corporate_url HP
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {
      company: {
        uid: "uid",
        name: "company name",
        name_reading_en: "company english name",
        zip_zode: "郵便番号",
        address1: "都道府県市町村区",
        address2: "番地 建物名",
        phone_no: "電話番号",
        plan_status: "スタンダード"
        count: 10
        admin_name: "admin_name"
        corporate_url: "http://example.com"
      }
    }

  @apiUse Unauthorized
  @apiUse UnprocessableEntity
=end
  def update
    if @company.update_attributes(update_params)
      render json: @company, status: 200
    else
      render_error('E03004', 'cannot_update_company', 422)
    end
  end

=begin
  @api {get} /api/company/setting_status SettingStatus
  @apiName SettingStatus
  @apiGroup Admin
  @apiDescription 設定の進捗を返す
  @apiPermission admin

  @apiSuccess {string} next_status
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {
      "next_status": 'CHATSETTING',
    }

  @apiUse Unauthorized
=end
  def setting_status
    if current_api_employee.admin
      if !current_api_employee.company
        render json: {next_status: 'COMPANY'}, status: 200
      elsif !current_api_employee.company.setting_chat_active?
        render json: {next_status: 'CHATSETTING'}, status: 200
      elsif !current_api_employee.company.test_notifier
        render json: {next_status: 'TESTNOTIFIER'}, status: 200
      elsif current_api_employee.company.setting_apps.none?(&:tablet_uid)
        render json: {next_status: 'TABLET'}, status: 200
      elsif current_api_employee.company.employees.count <= 1
        render json: {next_status: 'EMPLOYEE'}, status: 200
      else
        render json: {next_status: false}, status: 200
      end
    else
      render json: {next_status: false}, status: 200
    end
  end

=begin
  @api {post} /api/company/test_notifier TestNotifier
  @apiName TestNotifier
  @apiGroup Company
  @apiDescription 通知のテスト
  @apiPermission admin

  @apiSuccess {integer} chat_id
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {}

  @apiUse NotFound
=end
  def test_notifier
    scs = @company.setting_chats
    sc = scs.find_by(chat_id: Chat.find_by(name: params[:chat_name]).id)
    msg = nil
    msg = Notification.notify_test(sc)
    if msg
      render json: { error: { code: 'E03020', message: msg } }, status: 422
    else
      first_flag = false
      unless @company.test_notifier
        first_flag = true
        @company.update!(test_notifier: true)
      end
      render json: {first_flag: first_flag}, status: 200
    end
  end

  def restrict_employee_read
    if !current_api_employee.admin && !@company.employee_visitor_read && params[:all] == '1'
      render_error(nil, 'permission_denied', 403)
    end
  end

  def restrict_employee_download
    if !current_api_employee.admin && !@company.employee_visitor_download
      render_error(nil, 'permission_denied', 403)
    end
  end

 private

 def company_params
   params.require(:company)
   .permit(
     :uid,
     :name,
     :name_reading,
     :name_reading_en,
     :zipcode,
     :address1,
     :address2,
     :phone_no,
     :admin_name,
     :corporate_url
   )
 end

 def update_params
   params.require(:company)
   .permit(
     :name,
     :name_reading,
     :name_reading_en,
     :zipcode,
     :address1,
     :address2,
     :phone_no,
     :reception_mail_allowed,
     :admin_name,
     :corporate_url,
     :locale_code
   )
 end

 def employee_params
   params.require(:employee)
     .permit(
   :password,
   :name,
   :name_reading,
   :first_name,
   :last_name,
   :slack,
   :cw_id,
   :one_team,
   :ms_teams,
   :dingtalk
   )
 end

 def employee_update_params
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
       :slack_sub,
       :cw_id_sub,
       :one_team_sub,
       :ms_teams,
       :ms_teams_sub,
       :line_works,
       :line_works_sub,
       :dingtalk,
       :dingtalk_sub,
       :facebook_workplace,
       :facebook_workplace_sub
   )
 end

 def set_visitor_data
   # 全社員
   if params[:all] == '1'
     if current_api_employee.admin
       visitors = @company.visitors.includes(:appointment).visited
     else
       visible_visitors = @company.visitors.includes(:appointment).visited.visible
       own_visitors = @company.visitors.includes(:appointment).where(appointments: {employee_id: @current_api_employee.id}).visited.invisible
       visitors = visible_visitors + own_visitors
     end
     # サマリー
   elsif params[:chart]
     # use raw sql 'cos scope chain creates too many sqls
     date_start = Time.now-1.month
     date_end = Time.now
     query = "select * from visitors where \
      (company_id = #{@company.id}) AND \
      (visited_at is not NULL) AND \
      (visited_at between '#{date_start.to_s(:db)}' AND '#{date_end.to_s(:db)}')"
     results = Visitor.find_by_sql(query)
     visitors = Visitor.where(id: results.map{|i| i.id}) # convert array to active record

     set_chart_data(visitors)
   else
     # 個人
     visitors = current_api_employee.visitors.includes(:appointment).visited
   end
   @visitors = visitors.kind_of?(Array) ? visitors.sort_by{|v| v.visited_at}.reverse! : visitors.order_by_desc
 end

  def employee_admin_params
    params.require(:employee).
      permit(
        :uqid
    )
  end

  def check_appointments_finished
    @employee = Employee.find_by(uqid: params[:employee_uqid])
    if @employee.appointments
      if @employee.appointments.where(':now < begin_at', now: Time.zone.now).exists?
        render_error('E03002', 'disable_delete_host', 400)
      end
    end
  end

  def render_success(obj)
    render json: obj, staus: 200
  end

  def render_error(code, locale, status)
    render json: {
      error: {
        code: code,
        message: I18n.t(".controllers.companies." + locale)
      }
    }, status: status
  end

  def render_error_without_locale(code, message, status)
    render json: {
      error: {
        code: code,
        message: message
      }
    }, status: status
  end

  def set_chart_data(visitors)
    monthly_count = []
    display_types_array = []
    setting_apps = @company.setting_apps
    setting_apps.each do |app|
      types = %W(#{WITH_CODE} #{WITHOUT_CODE})
      display_types = %W(#{WITH_CODE} #{WITHOUT_CODE})
      customs = app.setting_customs.turning
      customs.map { |custom| types << custom.id; display_types << custom.text || custom.text_en }
      setting_app_visitors = visitors.select { |visitor| visitor.setting_app_id == app.id }
      monthly_count << Visitor.monthly_count(setting_app_visitors, types)
      display_types_array << display_types
    end
    is_invalid_data = monthly_count.flatten.all?{ |num| num.zero? }
    monthly_days = Visitor.monthly_days
    top_num_employees = visitors.top_num_employees
    visited_companies = visitors.visited_companies
    @data = {num: monthly_count, days: monthly_days, types: display_types_array, rank_num: top_num_employees, visited_companies: visited_companies, is_invalid: is_invalid_data, apps: setting_apps, employee_visitor_read: @company.employee_visitor_read, employee_visitor_download: @company.employee_visitor_download}
  end

end
