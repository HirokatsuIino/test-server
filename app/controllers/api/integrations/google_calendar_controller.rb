class Api::Integrations::GoogleCalendarController < ApplicationController
  before_action :login_employee_only! unless Rails.env.development?

  def availability_times
    google_auth
    host_uqids = params[:host_uqids]
    resource_ids = params[:resource_ids]
    if host_uqids.blank?
      host_uqids = [current_api_employee.uqid]
    end
    calendar_resources = SettingGc.free_busy_availability_times(@emp_google.auth_hash, resource_params, host_uqids, resource_ids)
    render json: calendar_resources, status: 200
  end

  def create_provisional_schedule
    appointment = Appointment.new(
        appointment_params.merge(
            gc_int: params[:scheduler] == 'google',
            code: generate_code,
            employee_id: current_api_employee.id,
            company_id: current_api_employee.company_id
        )
    )
    appointment.update(title: ['[仮]',get_default_title(params)].join) if appointment.title.nil?

    if appointment.valid?
      appointment.save

      hosts = []
      if params[:host_uids]
        params[:host_uids].each do |uid|
          employee = Employee.find_by(uqid: uid)
          hosts.push(employee)
        end
      end
      appointment.hosts << hosts

      appointment.hosts.each do |host|
        AppointmentMailer.notify_appointment_to_hosts(host, appointment, false).deliver_later
      end

      if params[:visitors]
        params[:visitors].each do |param|
          visitor = Visitor.find_by(email: uid)
          # ToDo 存在しない場合どうするか。
          if visitor.present?
            AppointmentMailer.notify_appointment(appointment, visitors).deliver_later
          end
        end
      end

      # google calendar連携
      if appointment.gc_int
        google_auth
        # 複数eidが存在するため、appointments の eidはNULLにし、
        SettingGc.create_provisional(
            @emp_google.auth_hash,
            appointment,
            params[:availability_times])
      end

      render json: appointment, status: 200
    else
      print(appointment.errors.details)
      render_error('E04000', 'invalid_datetime', 422)
    end
  end

  def prospective_date
    google_auth

    availability_times = []
    appointment = Appointment.find_by(uid: params[:appointment_uid], code: params[:code])
    if appointment.present?
      # Google カレンダーからイベント情報を取得する
      # get のみeventIdを指定できる仕様のようなので、リクエスト飛ぶが関係ないイベント取得もありうるのでgetで取得する
      eids = appointment.provisional_eids.split(",")
      for eid in eids do
        calendar_event = SettingGc.get_calendar_event(@emp_google.auth_hash, eid)
        if calendar_event.present?
          # リソース情報取得
          resource = {}
          calendar_event['attendees'].each do |attendee|
            if attendee[:resource]
              resource['name'] = attendee[:displayName]
              resource['eid'] = eid
              break
            end
          end
          time = {
              'start': calendar_event['start']['dateTime'],
              'end': calendar_event['end']['dateTime']
          }
          availability_times.push({
                                   'resource': resource,
                                   'time': time
                               })
        end
      end
      render json: {
          appointment: appointment,
          availability_times: availability_times
      }, status: 200
    else
      # ToDo エラー内容を適切なものに変更する
      render_error('E04000', 'invalid_datetime', 422)
    end
  end

  def create_confirm_schedule
    appointment = Appointment.find_by(uid: params[:appointment_uid], code: params[:code])
    if appointment.present?

      visitors = params[:visitors]
      if visitors.present?
        visitors = appointment.visitors.build
        visitors.update_attributes!(
            name: param[:name],
            company_name: param[:company_name],
            company_id: current_api_employee.company_id,
            employee_id: current_api_employee.id,
            provisional_eids: params[:eids]
        )
        # 他の訪問者の日程が決まっているか確認する
        prospective_visitor = appointment.visitors.find_by(provisional_eids: nil)
        if prospective_visitor.blank?
          # 他の訪問者の日程が決まっていればgoogleカレンダーを更新し、日程を確定する
          if appointment.gc_int
            google_auth

            # 登録された日程から本登録を行う
            visitor_eids = []
            for visitor in appointment.visitors do
              visitor_eids += JSON.parse(visitor.provisional_eids)
            end

            confirm_event_id = visitor_eids.group_by{|e| e}.sort_by{|_,v|-v.size}.map(&:first)
            # confirm_event_id = visitor_eids[0]
            # 仮で登録していた予定を本登録に変更
            appointment.update(title: [get_default_title(params)].join, eid: confirm_event_id) if appointment.title.nil?

            # 仮抑えしてある予定を削除する
            eids =  appointment.provisional_eids.split(',')
            for eid in eids do
              if eid != confirm_event_id
                SettingGc.delete(@emp_google.auth_hash, eid, 'primary')
              end
            end

            # 確定した場合、メールを送信する
            appointment.hosts.each do |host|
              AppointmentMailer.notify_appointment_to_hosts(host, appointment, false).deliver_later
            end
          end
        end
      end
    else
      # ToDo エラー内容を適切なものに変更する
      render_error('E04000', 'invalid_datetime', 422)
    end
  end

  def resource_availability
    google_auth
    calendar_resources = SettingGc.free_busy_resources(@emp_google.auth_hash, resource_params)
    calendar_resources.sort_by!{ |value| value["name"] } if calendar_resources.present?
    render json: calendar_resources, status: 200
  end

  def all_resources
    google_auth
    calendar_resources = SettingGc.all_resources(@emp_google.auth_hash)
    render json: calendar_resources, status: 200
  end

  private

  def appointment_params
    params.require(:appointment).permit(
        :title,
        :code,
        :description,
        :place,
        :begin_at,
        :end_at,
        :gc_int,
        :display,
        :outlook
    )
  rescue
    {}
  end

  def render_error(code, locale, status)
    render json: {
        error: {
            code: code,
            message: I18n.t(".controllers.google_calendar." + locale)
        }
    }, status: status
  end

  def resource_params
    timeMin = Time.zone.parse(params[:timeMin]).strftime("%Y-%m-%dT%H:%M:%S%:z")
    timeMax = Time.zone.parse(params[:timeMax]).strftime("%Y-%m-%dT%H:%M:%S%:z")
    {
      timeMin: timeMin,
      timeMax: timeMax
    }
  end

  def build_employee_google
    unless current_api_employee.employee_google
      EmployeeGoogle.create(employee_id: current_api_employee.id)
    end
  end

  def generate_code
    # 予定日の前後日で被らないコードを発行する
    day = Time.current.day
    last_digit = day.to_s.split('').last
    if day == '31'
      last_digit = [2, 3, 4, 5, 6, 7, 8, 9].sample.to_s
    end
    ("%05d" % SecureRandom.random_number(100_000)) << last_digit
  end

  def google_auth
    build_employee_google
    @emp_google = current_api_employee.employee_google
    auth_info = SettingGc.gc_auth(@emp_google.auth_hash, @emp_google.calendar_id)
    @emp_google.update(auth_hash: auth_info)
  end

  def get_default_title(params)
    I18n.locale == :ja ? "#{params[:visitors][0][:company_name]} : #{params[:visitors][0][:name]}様" : "#{params[:visitors][0][:company_name]} : #{params[:visitors][0][:name]}"
  end
end
