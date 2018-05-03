class Api::SettingAppsController < ApplicationController
  before_action :login_employee_only!
  before_action :admin! unless Rails.env.development?
  before_action :prepare_company
  before_action :validate_tablet_uid, except: [:index, :update_tablet, :reset_tablet] unless Rails.env.development?
  before_action :set_setting_app, except: :index
  before_action :check_setting_switches, only: :update unless Rails.env.test?
  before_action :validate_admission, only: :update
  before_action :update_custom_button_admission, only: :update

=begin
  @api {get} /api/chat/setting_apps IndexSettingApps
  @apiName IndexSettingApps
  @apiGroup Chat
  @apiDescription 受付アプリ設定情報の取得
  @apiPermission admin

  @apiSuccess {Object} setting_apps
  @apiSuccess {String} setting_apps.uid uid
  @apiSuccess {String} setting_apps.tablet_location 使用中のtabletの名前
  @apiSuccess {String} setting_apps.theme テーマ ('Light' or 'Dark')
  @apiSuccess {String} setting_apps.logo_url ロゴ画像
  @apiSuccess {String} setting_apps.bg_url 背景画像
  @apiSuccess {String} setting_apps.bg_rgb 背景RGB
  @apiSuccess {Integer} setting_apps.bg_default デフォルト背景画像 (1~6)
  @apiSuccess {String} setting_apps.text ロゴテキスト
  @apiSuccess {String} setting_apps.text_en ロゴテキスト(英語)
  @apiSuccess {String} setting_apps.done_text 完了テキスト
  @apiSuccess {String} setting_apps.done_text_en 完了テキスト(英語)
  @apiSuccess {Boolean} setting_apps.code 受付コードボタンの表示・非表示
  @apiSuccess {Boolean} setting_apps.search 社員検索ボタンの表示・非表示
  @apiSuccess {Boolean} setting_apps.input_name 名前入力ON/OFF
  @apiSuccess {Boolean} setting_apps.input_company 社名入力ON/OFF
  @apiSuccess {Boolean} setting_apps.input_number 人数入力ON/OFF
  @apiSuccess {string} setting_apps.tel_error 通知エラー時の連絡先

  @apiSuccessExample Success-Response:
  HTTP/1.1 200 OK
    {
      setting_apps: [
        {
          uid: "bla-bla-bla",
          tablet_uid: "xxxxxx",
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
          tel_error: '03-xxxx-xxxx',
          setting_customs: [
            {
              uid: "c466f07b-0158-464d-9fab-5644d61ed562",
              active: false,
              recording: true,
              input_name: true,
              input_company: false,
              input_number: true,
              email_to: null,
              msg: null,
              msg_en: null,
              text: "面接の方はこちら",
              text_en: "for job interview",
              mention_to: "channel",
              mention_in: "reception",
              cw_account_id: null,
              show_user_groups: false,
              slack_group: false,
              slack_group_id: null,
              button_type: 'notification',
              board_msg: null,
              board_msg_en: null,
              chat: {
                id: 1,
                uid: "6bc0de80-1432-40c0-8ec5-ada15ead826f",
                name: "Slack"
              },
            },
            {
              uid: "c466f07b-0158-464d-9fab-5644d61ed562",
              active: false,
              recording: false,
              input_name: false,
              input_company: false,
              input_number: false,
              email_to: null,
              msg: null,
              msg_en: null,
              text: "null",
              text_en: "null",
              mention_to: "null",
              mention_in: "null",
              cw_account_id: null,
              show_user_groups: false,
              slack_group: false,
              slack_group_id: null,
              button_type: 'msg_board',
              board_msg: '説明会へお越しの方はこのままx番のセミナールームへ移動してください',
              board_msg_en: 'Please go to seminar room x for company information session.'
            }
          ]
        },
        {
          uid: "bla-bla-bla",
          tablet_uid: "xxxxxx",
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
          tel_error: '03-xxxx-xxxx',
          setting_customs: [
            {
              uid: "c466f07b-0158-464d-9fab-5644d61ed562",
              active: false,
              recording: true,
              input_name: true,
              input_company: false,
              input_number: true,
              email_to: null,
              msg: null,
              msg_en: null,
              text: "面接の方はこちら",
              text_en: "for job interview",
              mention_to: "channel",
              mention_in: "reception",
              cw_account_id: null,
              show_user_groups: false,
              slack_group: false,
              slack_group_id: null,
              button_type: 'notification',
              board_msg: null,
              board_msg_en: null,
              chat: {
                id: 1,
                uid: "6bc0de80-1432-40c0-8ec5-ada15ead826f",
                name: "Slack"
              },
            },
            {
              uid: "c466f07b-0158-464d-9fab-5644d61ed562",
              active: false,
              recording: false,
              input_name: false,
              input_company: false,
              input_number: false,
              email_to: null,
              msg: null,
              msg_en: null,
              text: "null",
              text_en: "null",
              mention_to: "null",
              mention_in: "null",
              cw_account_id: null,
              show_user_groups: false,
              slack_group: false,
              slack_group_id: null,
              button_type: 'msg_board',
              board_msg: '説明会へお越しの方はこのままx番のセミナールームへ移動してください',
              board_msg_en: 'Please go to seminar room x for company information session.'
            }
          ]
        }
      ]
    }

  @apiUse Unauthorized
=end
  def index
    render json: current_api_employee.company.setting_apps
  end

=begin
  @api {put} /api/chat/setting_apps/:uid ShowSettingApp
  @apiName ShowSettingApp
  @apiGroup Chat
  @apiDescription 受付アプリ設定の表示
  @apiPermission admin

  @apiParam {Object} setting_app
  @apiParam {String} setting_app.uid uid
  @apiParam {String} setting_app.tablet_uid 使用中タブレットの端末ID
  @apiParam {String} setting_app.tablet_location 使用中タブレットの設置場所
  @apiParam {String} setting_app.theme テーマ ('Light' or 'Dark')
  @apiParam {File} setting_app.bg_url 背景画像
  @apiParam {String} setting_app.bg_rgb 背景RGB
  @apiParam {Integer} setting_app.bg_default デフォルト背景画像 (1~6)
  @apiParam {String} setting_app.logo_url ロゴ画像
  @apiParam {String} setting_app.text ロゴテキスト
  @apiParam {String} setting_app.done_text 完了テキスト
  @apiParam {String} setting_app.done_text_en 完了テキスト(英語)
  @apiParam {boolean} setting_app.code 受付コードボタンの表示・非表示
  @apiParam {boolean} setting_app.search 社員検索ボタンの表示・非表示
  @apiParam {Boolean} setting_app.input_name 名前入力ON/OFF
  @apiParam {Boolean} setting_app.input_company 社名入力ON/OFF
  @apiParam {Boolean} setting_app.input_number_code 受付コードでの人数入力ON/OFF
  @apiParam {Boolean} setting_app.input_number_search 社員検索後人数入力ON/OFF
  @apiParam {string} setting_app.tel_error 通知エラー時の連絡先

  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {
      setting_app: {
        uid: 'bla-bla-bla',
        tablet_uid: 'xxxxx',
        tablet_location: 'tablet 1',
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
        done_text: "完了しました",
        done_text_en: "done text",
        code: true,
        search: true,
        input_name: true,
        input_company: true,
        input_number_code: true,
        input_number_search: true,
        tel_error: '03-xxxx-xxxx',
        setting_customs: [
            {
              uid: "c466f07b-0158-464d-9fab-5644d61ed562",
              active: false,
              recording: true,
              input_name: true,
              input_company: false,
              input_number: true,
              email_to: null,
              msg: null,
              msg_en: null,
              text: "面接の方はこちら",
              text_en: "for job interview",
              mention_to: "channel",
              mention_in: "reception",
              cw_account_id: null,
              show_user_groups: false,
              slack_group: false,
              slack_group_id: null,
              button_type: 'notification',
              board_msg: null,
              board_msg_en: null,
              chat: {
                id: 1,
                uid: "6bc0de80-1432-40c0-8ec5-ada15ead826f",
                name: "Slack"
              },
            },
            {
              uid: "c466f07b-0158-464d-9fab-5644d61ed562",
              active: false,
              recording: false,
              input_name: false,
              input_company: false,
              input_number: false,
              email_to: null,
              msg: null,
              msg_en: null,
              text: "null",
              text_en: "null",
              mention_to: "null",
              mention_in: "null",
              cw_account_id: null,
              show_user_groups: false,
              slack_group: false,
              slack_group_id: null,
              button_type: 'msg_board',
              board_msg: '説明会へお越しの方はこのままx番のセミナールームへ移動してください',
              board_msg_en: 'Please go to seminar room x for company information session.'
            }
          ]
        }
      }
    }
  @apiUse Unauthorized
  @apiUse UnprocessableEntity

=end
  def show
    render_success(@setting_app)
  end

=begin
  @api {put} /api/chat/setting_apps/:uid UpdateSettingApp
  @apiName UpdateSettingApp
  @apiGroup Chat
  @apiDescription 受付アプリ設定の更新
  @apiPermission admin

  @apiParam {Object} setting_app
  @apiParam {String} setting_app.uid uid
  @apiParam {String} setting_app.tablet_uid 使用中タブレットの端末ID
  @apiParam {String} setting_app.tablet_location 使用中タブレットの設置場所
  @apiParam {String} setting_app.theme テーマ ('Light' or 'Dark')
  @apiParam {File} setting_app.bg_url 背景画像
  @apiParam {String} setting_app.bg_rgb 背景RGB
  @apiParam {Integer} setting_app.bg_default デフォルト背景画像 (1~6)
  @apiParam {String} setting_app.logo_url ロゴ画像
  @apiParam {String} setting_app.text ロゴテキスト
  @apiParam {String} setting_app.done_text 完了テキスト
  @apiParam {String} setting_app.done_text_en 完了テキスト(英語)
  @apiParam {boolean} setting_app.code 受付コードボタンの表示・非表示
  @apiParam {boolean} setting_app.search 社員検索ボタンの表示・非表示
  @apiParam {Boolean} setting_app.input_name 名前入力ON/OFF
  @apiParam {Boolean} setting_app.input_company 社名入力ON/OFF
  @apiParam {Boolean} setting_app.input_number_code 受付コードでの人数入力ON/OFF
  @apiParam {Boolean} setting_app.input_number_search 社員検索後人数入力ON/OFF
  @apiParam {string} setting_app.tel_error 通知エラー時の連絡先

  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {
      setting_app: {
        uid: 'bla-bla-bla',
        tablet_uid: 'xxxxx',
        tablet_location: 'tablet 1',
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
        done_text: "完了しました",
        done_text_en: "done text",
        code: true,
        search: true,
        input_name: true,
        input_company: true,
        input_number_code: true,
        input_number_search: true,
        tel_error: '03-xxxx-xxxx'
        }
      }
    }
  @apiUse Unauthorized
  @apiUse UnprocessableEntity

=end
  def update
    @setting_app.update_attributes!(setting_params)
    @setting_app.disable_setting_custom_admissions if @should_be_disable_setting_custom_admissions
    render_success(@setting_app)
  end

=begin
  @api {put} /api/chat/setting_apps/:setting_app_uid/tablet UpdateSettingAppTabletId
  @apiName UpdateSettingAppTabletId
  @apiGroup Chat
  @apiDescription 受付アプリ設定と端末IDの紐付け
  @apiPermission admin

  @apiParam {String} tablet_uid 使用中タブレットの端末ID

  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {
      setting_app: {
        uid: 'bla-bla-bla',
        tablet_uid: 'xxxxx',
        tablet_location: 'tablet 1',
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
        done_text: "完了しました",
        done_text_en: "done text",
        code: true,
        search: true,
        input_name: true,
        input_company: true,
        input_number_code: true,
        input_number_search: true,
        tel_error: '03-xxxx-xxxx'
        }
      }
    }
  @apiUse Unauthorized
  @apiUse UnprocessableEntity

=end
  def update_tablet
    if @setting_app.tablet_uid.present?
      render_error('E02015', 'already_connected', 400)
    else
      @setting_app.update_attributes!(tablet_uid: params[:tablet_uid])
      render_success(@setting_app)
    end
  end

=begin
  @api {delete} /api/chat/setting_apps/:setting_app_uid/logo DeleteSettingAppLogo
  @apiName DeleteSettingAppLogo
  @apiGroup Chat
  @apiDescription ロゴの削除
  @apiPermission admin

  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {
      setting_app: {
        theme: 'Light',
        logo_url: {
         logo_url: {
           url: nil,
           thumb: nil
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
        done_text: "完了しました",
        done_text_en: "done text",
        slack: "slack",
        search: true,
        input_name: true,
        input_company: true,
        input_number_code: true,
        input_number_search: true,
        tel_error: '03-xxxx-xxxx'
        }
      }
    }
  @apiUse Unauthorized
  @apiUse UnprocessableEntity

=end
  def delete_logo
    if @setting_app.logo_url?
      @setting_app.remove_logo_url!
      @setting_app.update_attributes!(logo_url: nil)
      render_success(@setting_app)
    else
      render_error('E02012', 'logo_not_found', 422)
    end
  end

=begin
  @api {delete} /api/chat/setting_apps/:setting_app_uid/bg DeleteSettingAppBg
  @apiName DeleteSettingAppBg
  @apiGroup Chat
  @apiDescription 背景画像の削除
  @apiPermission admin

  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {
      setting_app: {
        theme: 'Light',
        logo_url: {
         logo_url: {
           url: "https://receptionist/logo_url",
           thumb: "https://receptionist/logo_url_thumb"
         }
        },
        bg_url: {
         bg_url: {
           url: nil,
           thumb: nil
         }
        },
        bg_rgb: "ffffff",
        bg_default: 1,
        text: "ロゴテキスト",
        done_text: "完了しました",
        done_text_en: "done text",
        slack: "slack",
        search: true,
        input_name: true,
        input_company: true,
        input_number_code: true,
        input_number_search: true,
        tel_error: '03-xxxx-xxxx'
        }
      }
    }
  @apiUse Unauthorized
  @apiUse UnprocessableEntity

=end
  def delete_bg
    if @setting_app.bg_url?
      @setting_app.remove_bg_url!
      @setting_app.update_attributes!(bg_url: nil)
      render_success(@setting_app)
    else
      render_error('E02013', 'bg_not_found', 422)
    end
  end

=begin
  @api {delete} /api/chat/setting_apps/:setting_app_uid/reset DeleteSettingAppTabletId
  @apiName DeleteSettingAppTabletId
  @apiGroup Chat
  @apiDescription Tablet idのリセット
  @apiPermission admin

  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {
      setting_app: {
        theme: 'Light',
        logo_url: {
         logo_url: {
           url: "https://receptionist/logo_url",
           thumb: "https://receptionist/logo_url_thumb"
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
        done_text: "完了しました",
        done_text_en: "done text",
        slack: "slack",
        search: true,
        input_name: true,
        input_company: true,
        input_number_code: true,
        input_number_search: true,
        tel_error: '03-xxxx-xxxx'
        }
      }
    }
  @apiUse Unauthorized
  @apiUse UnprocessableEntity

=end
  def reset_tablet
    if @setting_app.tablet_uid
      @setting_app.update_attributes!(tablet_uid: nil)
      render_success(@setting_app)
    else
      render_error('E02014', 'tablet_not_found', 422)
    end
  end


  private

  def set_setting_app
    uid = params[:uid] ? params[:uid] : params[:setting_app_uid]
    @setting_app = @company.setting_apps.find_by(uid: uid)
    unless @setting_app.present?
      render_error('E02010', 'record_not_found', 400)
    end
  end

  def setting_params
    params.require(:setting_app)
    .permit(
      :tablet_location,
      :theme,
      :logo_url,
      :bg_url,
      :bg_rgb,
      :bg_default,
      :text,
      :done_text,
      :done_text_en,
      :code,
      :search,
      :input_name,
      :input_company,
      :input_number_code,
      :input_number_search,
      :tel_error,
      :admission_url,
      :admission,
      :monitoring,
      :monitoring_chat_id,
      :monitoring_mention_in,
      :monitor_begin_at,
      :monitor_end_at
    )
  end

  # 全てのボタンがOFFにならないようにする
  def check_setting_switches
    if (!@setting_app.setting_customs.any?(&:active) && @setting_app.code && !@setting_app.search && setting_params[:code] == false) || (!@setting_app.setting_customs.any?(&:active) && !@setting_app.code && @setting_app.search && setting_params[:search] == false)
      render_error('E02011', 'unable_switch_off', 400)
    end
  end

  def validate_admission
    if setting_params[:admission].class == String
      case setting_params[:admission]
      when "true"
        admission = true
      when "false"
        admission = false
      else
        admission = false
      end
    else
      admission = setting_params[:admission]
    end
    if admission && (!@setting_app.admission_url.present? || !setting_params[:admission_url].present?)
      render_error('E02016', 'admission_url_not_found', 422)
    end
  end

  def update_custom_button_admission
    if (!setting_params[:admission]) && (@setting_app.admission != setting_params[:admission])
      @should_be_disable_setting_custom_admissions = true
    end
  end

  def render_success(obj)
    render json: obj, staus: 200
  end

  def render_error(code, locale, status)
    render json: {
      error: {
        code: code,
        message: I18n.t(".controllers.setting_apps." + locale)
      }
    }, status: status
  end

end
