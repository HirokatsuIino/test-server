class Api::AppointmentsController < ApplicationController
  before_action :login_employee_only!
  before_action :prepare_company, only: [:create, :show, :detail, :destroy, :update]
  before_action :check_code_switch, only: :create
  before_action :validate_visitors, only: :create

=begin
  @api {post} /api/employee/appointment CreateAppointment
  @apiName CreateAppointment
  @apiGroup Employee
  @apiDescription アポの登録
  @apiPermission general

  @apiParam {Object} appointment
  @apiParam {String} appointment.title タイトル
  @apiParam {DateTime} appointment.begin_at 開始時間
  @apiparam {DateTime} appointment.end_at 終了時間
  @apiparam {DateTime} appointment.place 場所
  @apiParam {String} [appointment.description] 概要
  @apiParam {Object} host_uids 参加する社員のユニークIDの配列
  @apiParam {Object} visitor[]
  @apiParam {String} visitor.name 名前
  @apiparam {datetime} [visitor.company_name] 会社名
  @apiparam {datetime} [visitor.email] メールアドレス
  @apiparam {datetime} [visitor.company_name] 会社名
  @apiparam {datetime} [visitor.phone_no] 電話番号

  @apiSuccess {Object} appointment
  @apiSuccess {String} appointment.uid アポID
  @apiSuccess {String} appointment.title タイトル
  @apiSuccess {Date} appointment.begin_date 開始日
  @apiSuccess {DateTime} appointment.begin_at 開始時間
  @apiSuccess {DateTime} appointment.end_at 終了時間
  @apiSuccess {Boolean} appointment.edited 編集済みかどうか
  @apiSuccess {String} appointment.place 場所
  @apiSuccess {Object} visitors
  @apiSuccess {String} visitor.uid visitorID
  @apiSuccess {String} visitor.name 名前
  @apiSuccess {String} visitor.company_name 会社名
  @apiSuccess {String} visitor.email メールアドレス
  @apiSuccess {String} visitor.display 来訪記録への表示非表示
  @apiSuccess {DateTime} visitor.visited_at 訪問日
  @apiSuccess {Object} hosts
  @apiSuccess {String} host.email メール
  @apiSuccess {String} host.name 名前
  @apiSuccess {String} host.name_reading カナ
  @apiSuccess {String} host.name_reading_en 英語
  @apiSuccess {String} host.icon_uri プロフィール画像
  @apiSuccess {String} host.department 部署
  @apiSuccess {String} host.slack slack名
  @apiSuccess {String} host.active 登録状況
  @apiParamExample {json} Request-Example:

     host_uids: [
       {
        uqid: "**************"
       }
       {
        uqid: "**************"
       }
     ]
     visitors: [
      {
        name: 'name1',
        email: 'example1@gmail.com'
      },
      {
        name: 'name2',
        email: 'example2@gmail.com'
      }
     ]
  @apiSuccessExample Success-Response:
    HTTP/1.1 201 OK
    {
      appointment: {
        uid: "123123"
        title: "title"
        begin_date: "2017-08-20"
        begin_at: "2017-08-20 10:00"
        end_at: "2017-08-20 12:00"
        edited: false
        place: "会議室3"
        visitors: {
          id: 1
          name: "visitor"
          company_name: "visitor_company"
          email: "visitor@example.com"
          visited_at: null
          display: true
          appointment_id: 1
          company_id; 1
          employee_id: 1
          uid: "0000000"
        hosts: {
          id: 1
          email: "host@example.com"
          uid: "host@example.com"
          name: "name"
          name_reading: "name"
          phone_no: 090-0909-0909
          icon_uri {
            uri; null
            thumb: {
              uri: null
            }
          }
          company_id; 1
          admin: false
          department: "部署"
          provider: "email"
          active: true
          name_reading_en: "name"
          cw_id: 1
          cw_account_id: 1
        }
      }
    }

  @apiUse NotFound
=end
=begin
  curl localhost:3000/api/employee/appointment \
    -d 'appointment[title]=irregular appo by curl' \
    -d 'appointment[appo_type]=irregular' \
    -d 'appointment[place]=' \
    -d 'appointment[begin_date]=2018-03-01' \
    -d 'appointment[end_date]=2018-03-31' \
    -d 'appointment[visitors][][name]=name' \
    -d 'appointment[visitors][][company_name]=company_name' \
    -d 'appointment[visitors][][email]=' \
    -d 'appointment[host_uids][]=b71dc068-20ff-41c7-ba5a-84c7eecccd4f' \
    -d 'code_only=1'
=end
  def create
    appointment = Appointment.new(
      appointment_params.merge(
        code_only: params[:code_only],
        employee_id: current_api_employee.id,
        company_id: current_api_employee.company_id
      )
    )
    appointment.update(title: get_default_title(params)) if appointment.title.nil?
    appointment.update(code: nil) if appointment.onetime?

    if appointment.valid_code?
      if appointment.valid?
        appointment.save

        # create hosts
        hosts = []
        if params[:host_uids]
          params[:host_uids].each do |uid|
            employee = Employee.find_by(uqid: uid)
            hosts.push(employee)
          end
        end
        appointment.hosts << hosts

        # mailer to host
        appointment.hosts.each do |host|
          if appointment.onetime?
            AppointmentMailer.notify_appointment_to_hosts(host, appointment, appointment.code_only).deliver_later
          elsif appointment.irregular?
            AppointmentMailer.notify_irregular_appointment_to_hosts(host, appointment, appointment.code_only).deliver_later
          end
        end

        # create visitors and mailer to them
        if params[:visitors]
          params[:visitors].each do |param|
            visitors = appointment.visitors.build
            visitors.update_attributes!(
              name: param[:name],
              email: param[:email],
              company_name: param[:company_name],
              company_id: current_api_employee.company_id,
              employee_id: current_api_employee.id,
              display: appointment.display
            )
            unless appointment.code_only
              if appointment.onetime?
                AppointmentMailer.notify_appointment(appointment, visitors).deliver_later
              elsif appointment.irregular?
                AppointmentMailer.notify_irregular_appointment(appointment, visitors).deliver_later
              end
            end
          end
        end

        # integration with calendar apps
        if appointment.onetime?
          p 'appointment.onetime?'
          # google calendar
          if appointment.gc_int
            p 'appointment.gc_int'
            google_auth
            p 'google_auth'
            appointment.update(calendar_id: params[:calendar_id][:id])
            @emp_google.update(calendar_id: params[:calendar_id][:id])
            eid = SettingGc.create(@emp_google.auth_hash, appointment, appointment.calendar_id, params[:resource_id])
            appointment.update(eid: eid) if eid
          end
          # outlook
          if appointment.outlook
            p 'appointment.outlook'
            employee = MicrosoftService.new current_api_employee
            p 'MicrosoftService.new'
            p employee
            event_details = employee.save_appo_to_outlook appointment
            appointment.update_attributes!(eid: event_details['id'])
          end
        end

        render json: appointment, status: 201
      else
        render_error('E04000', 'invalid_datetime', 422)
      end
    else
      render_error('E04002', 'invalid_code', 422)
    end
  end

=begin
  @api {get} /api/employee/appointment IndexAppointments
  @apiName IndexAppointments
  @apiGroup Employee
  @apiDescription 会社アポ一覧・個人アポ一覧
  @apiPermission general

  @apiParam {Boolean} all 全取得

  @apiSuccess {Object} appointment
  @apiSuccess {String} appointment.uid アポID
  @apiSuccess {String} appointment.title タイトル
  @apiSuccess {Date} appointment.begin_date 開始日
  @apiSuccess {DateTime} appointment.begin_at 開始時間
  @apiSuccess {DateTime} appointment.end_at 終了時間
  @apiSuccess {Boolean} appointment.edited 編集済みかどうか
  @apiSuccess {String} appointment.place 場所
  @apiSuccess {Object} visitors
  @apiSuccess {String} visitor.uid visitorID
  @apiSuccess {String} visitor.name 名前
  @apiSuccess {String} visitor.company_name 会社名
  @apiSuccess {String} visitor.email メールアドレス
  @apiSuccess {String} visitor.phone_no 電話番号
  @apiSuccess {DateTime} visitor.visited_at 訪問日
  @apiSuccess {Object} hosts
  @apiSuccess {String} host.email メール
  @apiSuccess {String} host.name 名前
  @apiSuccess {String} host.name_reading カナ
  @apiSuccess {String} host.name_reading_en 英語
  @apiSuccess {String} host.icon_uri プロフィール画像
  @apiSuccess {String} host.department 部署
  @apiSuccess {String} host.slack slack名
  @apiSuccess {String} host.active 登録状況
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {
      appointments: {
        id: 1
        name: "name"
        title: "title"
        begin_date: "2017-08-20"
        begin_at: "2017-08-20 10:00"
        end_at: "2017-08-20 12:00"
        edited: false
        place: "会議室3"
        visitors: {
          id: 1
          name: "visitor"
          company_name: "visitor_company"
          email: "visitor@example.com"
          phone_no: 090-0909-0909
          visited_at: null
          appointment_id: 1
          company_id; 1
          employee_id: 1
          uid: "0000000"
        hosts: {
          id: 1
          email: "host@example.com"
          uid: "host@example.com"
          name: "name"
          name_reading: "name"
          phone_no: 090-0909-0909
          icon_uri {
            uri; null
            thumb: {
              uri: null
            }
          }
          company_id; 1
          admin: false
          department: "部署"
          provider: "email"
          active: true
          name_reading_en: "name"
          cw_id: 1
          cw_account_id: 1
        }
      }
    }

  @apiUse NotFound
=end
  def show
    appointments = []
    if params[:type] == 'irregular'
      appointments = @company.appointments.where(appo_type: 1).includes(:hosts, :visitors).available_irregular_apppointmnet if current_api_employee.admin
    elsif params[:type] == 'all' || params[:all] == '1'
      appos = @company.appointments.where(appo_type: 0).includes(:hosts, :visitors).after_current_time
      if current_api_employee.admin
        appointments = appos
      else
        appointments = []
        appos.map do |appointment|
          if appointment.display || (appointment.display == false && appointment.hosts.any?{|e| e.id == current_api_employee.id} )
            appointments << appointment
          end
        end
      end
    else
      appointments = current_api_employee.appointments.where(appo_type: 0).includes(:hosts, :visitors).after_current_time.uniq
    end
    render json: appointments, status: 200
  end

=begin
  @api {get} /api/employee/appointment/detail ShowAppointment
  @apiName ShowAppointment
  @apiGroup Employee
  @apiDescription アポの詳細
  @apiPermission general

  @apiParam {String} appointment_uid アポID

  @apiSuccess {Object} appointment
  @apiSuccess {String} appointment.uid アポID
  @apiSuccess {String} appointment.title タイトル
  @apiSuccess {Date} appointment.begin_date 開始日
  @apiSuccess {DateTime} appointment.begin_at 開始時間
  @apiSuccess {DateTime} appointment.end_at 終了時間
  @apiSuccess {Boolean} appointment.edited 編集済みかどうか
  @apiSuccess {String} appointment.place 場所
  @apiSuccess {Object} visitors
  @apiSuccess {String} visitor.uid visitorID
  @apiSuccess {String} visitor.name 名前
  @apiSuccess {String} visitor.company_name 会社名
  @apiSuccess {String} visitor.email メールアドレス
  @apiSuccess {String} visitor.phone_no 電話番号
  @apiSuccess {DateTime} visitor.visited_at 訪問日
  @apiSuccess {Object} hosts
  @apiSuccess {String} host.email メール
  @apiSuccess {String} host.name 名前
  @apiSuccess {String} host.name_reading カナ
  @apiSuccess {String} host.name_reading_en 英語
  @apiSuccess {String} host.icon_uri プロフィール画像
  @apiSuccess {String} host.department 部署
  @apiSuccess {String} host.slack slack名
  @apiSuccess {String} host.active 登録状況
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {
      appointment: {
        id: 1
        name: "name"
        title: "title"
        begin_date: "2017-08-20"
        begin_at: "2017-08-20 10:00"
        end_at: "2017-08-20 12:00"
        edited: false
        place: "会議室3"
        visitors: {
          id: 1
          name: "visitor"
          company_name: "visitor_company"
          email: "visitor@example.com"
          phone_no: 090-0909-0909
          visited_at: null
          appointment_id: 1
          company_id; 1
          employee_id: 1
          uid: "0000000"
        hosts: {
          id: 1
          email: "host@example.com"
          uid: "host@example.com"
          name: "name"
          name_reading: "name"
          phone_no: 090-0909-0909
          icon_uri {
            uri; null
            thumb: {
              uri: null
            }
          }
          company_id; 1
          admin: false
          department: "部署"
          provider: "email"
          active: true
          name_reading_en: "name"
          cw_id: 1
          cw_account_id: 1
        }
      }
    }

  @apiUse NotFound
=end
  def detail
    appointment = @company.appointments.find_by(uid: params[:appointment_uid])
    render json: appointment, status: 200
  end

=begin
  @api {delete} /api/employee/appointment DeleteAppointment
  @apiName DeleteAppointment
  @apiGroup Employee
  @apiDescription アポの削除
  @apiPermission general

  @apiParam {String} uid アポID
  @apiSuccessExample Success-Response:
    HTTP/1.1 200 OK
    {}

  @apiUse NotFound
=end
  def destroy
    appointment = @company.appointments.find_by(uid: params[:appointment_uid])
    appointment.destroy!

    # google calendar連携(event_idが存在時)
    if appointment.eid && appointment.calendar_id && current_api_employee.employee_google
      if current_api_employee.employee_google.auth_hash
        google_auth
        SettingGc.delete(@emp_google.auth_hash, appointment.eid, appointment.calendar_id)
      end
    end
    #outlook
    if current_api_employee.employee_microsoft.try(:auth_hash) #this can caseu err, fix it
      appo = MicrosoftService.new current_api_employee
      appo.delete_appo_from_outlook appointment.eid
    end

    render json: {}, status: 200
  end

=begin
  @api {post} /api/employee/appointment UpdateAppointment
  @apiName UpdateAppointment
  @apiGroup Employee
  @apiDescription アポの編集
  @apiPermission general


  @apiParam {Integer} uid アポID
  @apiParam {Object} appointment
  @apiParam {String} appointment.title タイトル
  @apiParam {DateTime} appointment.begin_at 開始時間
  @apiparam {DateTime} appointment.end_at 終了時間
  @apiparam {DateTime} appointment.place 場所
  @apiParam {String} [appointment.description] 概要
  @apiParam {Object} host[]
  @apiParam {String} host.uqid 参加する社員のユニークID
  @apiParam {Object} visitor[]
  @apiParam {String} visitor.name 名前
  @apiparam {datetime} [visitor.company_name] 会社名
  @apiparam {datetime} [visitor.email] メールアドレス
  @apiparam {datetime} [visitor.company_name] 会社名
  @apiparam {datetime} [visitor.phone_no] 電話番号

  @apiSuccess {Object} appointment
  @apiSuccess {String} appointment.uid アポID
  @apiSuccess {String} appointment.title タイトル
  @apiSuccess {Date} appointment.begin_date 開始日
  @apiSuccess {DateTime} appointment.begin_at 開始時間
  @apiSuccess {DateTime} appointment.end_at 終了時間
  @apiSuccess {Boolean} appointment.edited 編集済みかどうか
  @apiSuccess {String} appointment.place 場所
  @apiSuccess {Object} visitors
  @apiSuccess {String} visitor.uid visitorID
  @apiSuccess {String} visitor.name 名前
  @apiSuccess {String} visitor.company_name 会社名
  @apiSuccess {String} visitor.email メールアドレス
  @apiSuccess {String} visitor.phone_no 電話番号
  @apiSuccess {DateTime} visitor.visited_at 訪問日
  @apiSuccess {Object} hosts
  @apiSuccess {String} host.email メール
  @apiSuccess {String} host.name 名前
  @apiSuccess {String} host.name_reading カナ
  @apiSuccess {String} host.name_reading_en 英語
  @apiSuccess {String} host.icon_uri プロフィール画像
  @apiSuccess {String} host.department 部署
  @apiSuccess {String} host.slack slack名
  @apiSuccess {String} host.active 登録状況
  @apiParamExample {json} Request-Example:

     host: [
       { uqid: "12345"
       }
       { uqid: "6789"
       }
     ]
     visitor: [
      { name: 'name1',
        email: 'example1@gmail.com'
      }
      { name: 'name2',
        email: 'example2@gmail.com'
      }
      ]
  @apiSuccessExample Success-Response:
    HTTP/1.1 201 OK
    {
      appointment: {
        id: 1
        name: "name"
        title: "title"
        begin_date: "2017-08-20"
        begin_at: "2017-08-20 10:00"
        end_at: "2017-08-20 12:00"
        edited: false
        place: "会議室3"
        visitors: {
          id: 1
          name: "visitor"
          company_name: "visitor_company"
          email: "visitor@example.com"
          phone_no: 090-0909-0909
          visited_at: null
          appointment_id: 1
          company_id; 1
          employee_id: 1
          uid: "0000000"
        hosts: {
          id: 1
          email: "host@example.com"
          uid: "host@example.com"
          name: "name"
          name_reading: "name"
          phone_no: 090-0909-0909
          icon_uri {
            uri; null
            thumb: {
              uri: null
            }
          }
          company_id; 1
          admin: false
          department: "部署"
          provider: "email"
          active: true
          name_reading_en: "name"
          cw_id: 1
          cw_account_id: 1
        }
      }
    }
  @apiUse NotFound
=end
  def update
    @appointment = @company.appointments.find_by(uid: params[:appointment_uid])
    check_if_deliver
    @old_hosts = @appointment.hosts.map { |host| host.email}
    begin
      @appointment.update(resource_id: nil) if @appointment.place != update_params[:place] && update_params[:place].present?
      @appointment.update_attributes! update_params.merge(
        edited: true
      )

      hosts = []
      if params[:host_uids]
        @appointment.hosts.clear
        params[:host_uids].uniq.each do |uid|
          employee = Employee.find_by(uqid: uid)
          hosts.push(employee)
        end
      end
      @appointment.hosts << hosts


      if params[:visitors]
        visitors_uid = @appointment.visitors.pluck(:uid)
        params[:visitors].each do |param|
          if param[:uid]
            visitor = @appointment.visitors.find_by(uid: param[:uid])
            visitor.update_attributes!(
              name: param[:name],
              email: param[:email],
              company_name: param[:company_name],
            )
            visitors_uid.delete(param[:uid])
          else
            visitors = Visitor.new(
              name: param[:name],
              email: param[:email],
              company_name: param[:company_name],
              company_id: current_api_employee.company_id,
              employee_id: current_api_employee.id,
              appointment_id: @appointment.id
            )
            visitors.save!
          end
        end
        visitors_uid.each do |uid|
          visitor = @appointment.visitors.find_by(uid: uid)
          visitor.destroy
        end
      end

      if @deliver
        # deliver mail to hosts and visitors
        @appointment.hosts.each do |host|
          AppointmentMailer.notify_appointment_update_to_hosts(host, @appointment).deliver_later if @appointment.onetime?
          AppointmentMailer.notify_irregular_appointment_update_to_hosts(host, @appointment).deliver_later if @appointment.irregular?
        end
        @appointment.visitors.each do |visitor|
          AppointmentMailer.notify_appointment_update(@appointment, visitor).deliver_later if @appointment.onetime?
          AppointmentMailer.notify_irregular_appointment_update(@appointment, visitor).deliver_later if @appointment.irregular?
        end
      end

      # google calendar連携(event_idが存在時)
      if @appointment.eid && @appointment.calendar_id && current_api_employee.employee_google
        if current_api_employee.employee_google.auth_hash
          google_auth
          SettingGc.update(@emp_google.auth_hash, @appointment.eid, @appointment, @appointment.calendar_id, params[:resource_id], @old_hosts)
        end
      end
      #outlook
      if current_api_employee.employee_microsoft.try(:auth_hash)
        appo = MicrosoftService.new current_api_employee
        appo.update_appo_in_outlook @appointment
      end

      render json: @appointment, status: 200
    rescue => e
      render_error('E04001', 'invalid_datetime_update', 422)
    end
  end


  private

  def appointment_params
    params.require(:appointment).permit(
      :appo_type,
      :title,
      :description,
      :place,
      :code,
      :begin_date,
      :begin_at,
      :end_date,
      :end_at,
      :gc_int,
      :display,
      :outlook
    )
  end

  def update_params
    params.require(:appointment).permit(
      :title,
      :description,
      :place,
      :begin_at,
      :begin_date,
      :end_at,
      :end_date,
      :display
    )
  end

  def check_if_deliver
    if @appointment.code_only
      @deliver = false
    else
      begin_at = @appointment.begin_at
      end_at = @appointment.end_at
      begin_param = DateTime.parse(update_params[:begin_at])
      end_param = DateTime.parse(update_params[:end_at])

      visitors = @appointment.visitors.size
      hosts = @appointment.hosts.size
      host_params = params[:host_uids].size if params[:host_uids]
      visitor_params = params[:visitor].size if params[:visitor]

      # 日付が変更されたか、visitorもしくはhostが変更された場合
      if  date_changed?(begin_at, begin_param, end_at, end_param) || host_visitor_changed?(hosts, host_params, visitors, visitor_params)
        @deliver = true
      end
    end
  end

  # 日付が変更されたか
  def date_changed?(begin_before, begin_after, end_before, end_after)
    begin_before != begin_after || end_before != end_after
  end

  # host か visitorが変更されたか
  def host_visitor_changed?(host_before=nil, host_after=nil, visitor_before=nil, visitor_after=nil)
    return false unless  visitor_after || host_after
    host_before != host_after || visitor_before != visitor_after
  end

  def build_employee_google
    unless current_api_employee.employee_google
      EmployeeGoogle.create(employee_id: current_api_employee.id)
    end
  end

  def google_auth
    build_employee_google
    @emp_google = current_api_employee.employee_google
    auth_info = SettingGc.gc_auth(@emp_google.auth_hash, @emp_google.calendar_id)
    @emp_google.update(auth_hash: auth_info)
  end

  def render_error(code, locale, status)
    render json: {
      error: {
        code: code,
        message: I18n.t(".controllers.appointments." + locale)
      }
    }, status: status
  end

  #受付コード表示がOFFの場合は作成できないようにする
  def check_code_switch
    if @company.setting_apps.none?(&:code)
      render_error('E', 'disable_code', 422)
    end
  end

  def validate_visitors
    if params[:visitors].present?
      visitors_form = Appointments::CreateForm.new(params)
      render json: { message: visitors_form.errors.full_messages[0] }, status: 400 and return unless visitors_form.valid?
    end
  end

  def get_default_title(params)
    I18n.locale == :ja ? "#{params[:visitors][0][:company_name]} : #{params[:visitors][0][:name]}様" : "#{params[:visitors][0][:company_name]} : #{params[:visitors][0][:name]}"
  end
end
