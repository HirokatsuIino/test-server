# == Schema Information
#
# Table name: setting_gcs
#
#  id         :integer          not null, primary key
#  gc_token   :string(255)
#  gc_id      :string(255)
#  company_id :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

require 'google/api_client'
#require 'google/apis/admin_directory_v1'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/installed_app'
require 'google/api_client/auth/file_storage'
require 'date'
require 'net/https'
require 'pp'

class SettingGc < ActiveRecord::Base
  belongs_to :company
  mount_uploader :gc_token, GaTokenUploader

  path = '/appointments/new'
  REDIRECT_URI = Constants::WEB_ROOT + path
  API_SCOPE = ['https://www.googleapis.com/auth/calendar', 'https://www.googleapis.com/auth/admin.directory.resource.calendar']
  MAX_RESOURCE_SIZE = 20

  def self.create(auth_hash, appointment, calendar_id, resource_id)
    gc_auth(auth_hash, calendar_id)
    start_date = appointment.begin_at.strftime("%Y-%m-%dT%H:%M:%S%:z")
    end_date = appointment.end_at.strftime("%Y-%m-%dT%H:%M:%S%:z")
    summary = appointment.title
    location = appointment.place
    appointment_code = "[RN#{appointment.code}]\s"

    attendee = []
    appointment.hosts.each do |host|
      attendee_body = {
        "optional": true,
        "responseStatus": "needsAction"
      }
      attendee_body[:email] = host.email
      attendee.push(attendee_body)
    end
    cal = @client.discovered_api('calendar', 'v3')

    event = {
      'summary' => appointment_code + summary,
      'start' => {
        'dateTime' => start_date,
      },
      'end' => {
        'dateTime' => end_date,
      },
      "attendees": attendee,
      "location": location,
      "description": summary
      # "guestsCanModify": true
    }
    unless appointment.display
      event[:visibility] = 'private'
    end

    if resource_id.present?
      event[:location] = resource_id[:name]
      resource_attendee = {
        'responseStatus': 'accepted',
        'email': resource_id[:id]
      }
      event[:attendees].push(resource_attendee)
      appointment.update_attributes!(place: event[:location], resource_id: resource_id[:id])
    end
    attendee.each do |host|
      @client.execute(:api_method => cal.acl.insert,
                      :parameters => {'calendarId' => @calendar_id},
                      :body => JSON.dump({
                        "role": "owner",
                        "scope":
                        {
                          "type": "user",
                          "value": host[:email]
                        }
                      }),
                      :headers => {'Content-Type' => 'application/json'})
    end
    result = @client.execute(:api_method => cal.events.insert,
                            :parameters => {'calendarId' => @calendar_id},
                            :body => JSON.dump(event),
                            :headers => {'Content-Type' => 'application/json'})
    return result.data.try(:id)
  end

  def self.create_provisional(auth_hash, appointment, availability_times)
    # resourceが空の場合は終了
    return unless availability_times.present?

    gc_auth(auth_hash, appointment.calendar_id)

    attendee = []
    appointment.hosts.each do |host|
      attendee_body = {
          "optional": true,
          "responseStatus": "needsAction"
      }
      attendee_body[:email] = host.email
      attendee.push(attendee_body)
    end
    cal = @client.discovered_api('calendar', 'v3')

    # 指定された日時でリソースの空きをチェックする
    event_ids = []
    availability_times.each do |availability_time|
      resource = availability_time[:resource]
      datetimes = availability_time[:time]
      # 登録用のデータ生成
      event = {
          'summary' => appointment.title,
          'start' => {
              'dateTime' => datetimes[:start],
          },
          'end' => {
              'dateTime' => datetimes[:end],
          },
          "attendees": attendee,
          "description": summary
      }
      unless appointment.display
        event[:visibility] = 'private'
      end
      res = @client.execute(:api_method => cal.freebusy.query,
                            :body => JSON.dump(free_busy_params([resource[:id]],
                                                                {
                                                                     'timeMin' => datetimes[:start],
                                                                     'timeMax' => datetimes[:end]
                                                                 })),
                            :headers => {'Content-Type' => 'application/json'})

      if res.status == 200
        results = JSON.parse(res.body)
        results['calendars'].map do |calendar|
          # set availabilities
          if calendar[1]['busy'].blank? && list[index]['write_access']
            attendee.each do |host|
              @client.execute(:api_method => cal.acl.insert,
                              :parameters => {'calendarId' => appointment.calendar_id},
                              :body => JSON.dump({
                                                     "role": "owner",
                                                     "scope":
                                                         {
                                                             "type": "user",
                                                             "value": host[:email]
                                                         }
                                                 }),
                              :headers => {'Content-Type' => 'application/json'})

            end
            result = @client.execute(:api_method => cal.events.insert,
                                     :parameters => {'calendarId' => appointment.calendar_id},
                                     :body => JSON.dump(event),
                                     :headers => {'Content-Type' => 'application/json'})
            event_ids.push(result.data.try(:id))
            break
          end
        end
        appointment.update_attributes!(attributes: {'eid': event_ids})
      end
    end
  end

  def self.update(auth_hash, eid, appointment, calendar_id, resource_id, old_hosts)
    gc_auth(auth_hash, calendar_id)
    start_date = appointment.begin_at.strftime("%Y-%m-%dT%H:%M:%S%:z")
    end_date = appointment.end_at.strftime("%Y-%m-%dT%H:%M:%S%:z")
    summary = appointment.title
    location = appointment.place
    appointment_code = "[RN#{appointment.code}]\s"
    attendee = []
    appointment.hosts.each do |host|
      attendee_body = {
        "optional": true,
        "responseStatus": "needsAction"
      }
      attendee_body[:email] = host.email
      attendee.push(attendee_body)
    end

    if appointment.resource_id.present? && !resource_id.present?
      resource_attendee_params = {
        'responseStatus': 'accepted',
        'email': appointment.resource_id
      }
      attendee.push(resource_attendee_params)
    end

    cal = @client.discovered_api('calendar', 'v3')

    event = {
      'summary' => appointment_code + summary,
      'start' => {
        'dateTime' => start_date,
      },
      'end' => {
        'dateTime' => end_date,
      },
      "attendees": attendee,
      "location": location,
      "description": summary
      # "guestsCanModify": true
    }


    if resource_id.present?
      event[:location] = resource_id[:name]
      resource_attendee = {
        'responseStatus': 'accepted',
        'email': resource_id[:id]
      }
      event[:attendees].push(resource_attendee)

      appointment.update_attributes!(place: event[:location], resource_id: resource_id[:id])
    end
    removed_hosts = old_hosts - appointment.hosts.map {|host| host.email}
    removed_hosts.each do |host|
      @client.execute(:api_method => cal.acl.delete,
                      :parameters => {'calendarId' => @calendar_id, 'ruleId' => "user:#{host}"},
                      :headers => {'Content-Type' => 'application/json'})
    end unless removed_hosts.empty?
    attendee.each do |host|
      @client.execute(:api_method => cal.acl.insert,
                      :parameters => {'calendarId' => @calendar_id},
                      :body => JSON.dump({
                         "role": "owner",
                         "scope":
                        {
                           "type": "user",
                           "value": host[:email]
                         }
                      }),
                      :headers => {'Content-Type' => 'application/json'})
    end
    @client.execute(:api_method => cal.events.update,
                            :parameters => {'calendarId' => @calendar_id, 'eventId'=> eid},
                            :body => JSON.dump(event),
                            :headers => {'Content-Type' => 'application/json'})
  end

  def self.delete(auth_hash, eid, calendar_id)
    gc_auth(auth_hash, calendar_id)
    cal = @client.discovered_api('calendar', 'v3')
    @client.execute(:api_method => cal.events.delete,
                    :parameters => {'calendarId' => @calendar_id, 'eventId' => eid})
  end

  def self.get_calendar_lists(auth_hash)
    gc_auth(auth_hash, "hoge")
    cal = @client.discovered_api('calendar', 'v3')
    res = @client.execute(:api_method => cal.calendar_list.get,
                    :parameters => {'calendarId' => 'primary'},
                    :headers => {'Content-Type' => 'application/json'})
    calendar_lists = []
    if res.status == 200
      results = JSON.parse(res.body)
      ids = {}
      ids['summary'] = results['summary']
      ids['id'] = results['id']
      calendar_lists << ids
    end
    calendar_lists
  end

  def self.get_valid_resources
    cal = @client.discovered_api('calendar', 'v3')
    res = @client.execute(:api_method => cal.calendar_list.list,
                    :parameters => {
                                    'calendarId': 'my_customer',
                                    'showHidden': true,
                                    'minAccessRole': 'freeBusyReader'
                                   },
                    :headers => {'Content-Type' => 'application/json'})
    valid_resources = {}
    valid_resource_ids = []
    valid_resource_roles = {}
    if res.status == 200
      results = JSON.parse(res.body)
      if results['items'].present?
        results['items'].each do |item|
          item_id = item['id']
          valid_resource_ids << item_id
          valid_resource_roles[item_id] = item['accessRole'] != 'freeBusyReader'
        end
      end
    end
    valid_resources[:ids] = valid_resource_ids
    valid_resources[:roles] = valid_resource_roles
    valid_resources
  end

  def self.get_resource_list(resource_ids=nil)
    resource = @client.discovered_api('admin', 'directory_v1')
    res = @client.execute(:api_method => resource.resources.calendars.list,
                    :parameters => {'customer' => 'my_customer'},
                    :headers => {'Content-Type' => 'application/json'})
    resource_lists = []
    if res.status == 200
      results = JSON.parse(res.body)
      valid_resources = get_valid_resources
      results['items'].map do |item|
        next unless valid_resources[:ids].include?(item['resourceEmail'])
        if resource_ids.blank? || resource_ids.include?(item['resourceEmail'])
          ids = {}
          ids['id'] = item['resourceEmail']
          ids['resourceName'] = item['resourceName']
          ids['write_access'] = valid_resources[:roles][item['resourceEmail']]
          resource_lists << ids
        end
      end
    end
    resource_lists
  end

  def self.get_all_resource_list
    resource = @client.discovered_api('admin', 'directory_v1')
    res = @client.execute(:api_method => resource.resources.calendars.list,
                    :parameters => {'customer' => 'my_customer'},
                    :headers => {'Content-Type' => 'application/json'})
    result = nil
    result = JSON.parse(res.body) if res.status == 200
    result
  end

  def self.get_employees_list(employee_ids, employee_uqids=nil)
    if employee_uqids.blank?
      employees = Employee.where(id: employee_ids)
    else
      employees = Employee.where(uqid: employee_uqids)
    end
    resource_lists = []
    if employees.present?
      valid_resources = get_valid_resources
      employees.each do |employee|
        next unless valid_resources[:ids].include?(employee.email)
        ids = {}
        ids['id'] = employee.email
        ids['resourceName'] = employee.name
        ids['write_access'] = valid_resources[:roles][employee.email]
        resource_lists << ids
      end
    end
    resource_lists
  end

  def self.get_employees_customer_id
    directory = @client.discovered_api('admin', 'directory_v1')
    res = @client.execute(:api_method => directory..users.list,
                          :parameters => {'customer' => 'my_customer'},
                          :headers => {'Content-Type' => 'application/json'})
    resource_lists = []
    if res.status == 200
      results = JSON.parse(res.body)
      valid_resources = get_valid_resources
      results['items'].map do |item|
        next unless valid_resources[:ids].include?(item['resourceEmail'])
        ids = {}
        ids['id'] = item['resourceEmail']
        ids['resourceName'] = item['resourceName']
        ids['write_access'] = valid_resources[:roles][item['resourceEmail']]
        resource_lists << ids
      end
    end
    resource_lists
  end

  def self.check_calendar(auth_hash)
    gc_auth(auth_hash, nil)
    resources = get_all_resource_list
    return unless resources.present?
    valid_resources = get_valid_resources
    resources['items'].each do |resource|
      add_calendar(resource['resourceEmail']) unless valid_resources[:ids].include?(resource['resourceEmail'])
    end
  end

  def self.add_calendar(id)
    cal = @client.discovered_api('calendar', 'v3')
    @client.execute(api_method: cal.calendar_list.insert,
                    body: JSON.dump({id: id, hidden: true}),
                    headers: {'Content-Type' => 'application/json'})
  end

  def self.get_calendar_event(auth_hash, eventId)
    gc_auth(auth_hash, "")
    calendar = @client.discovered_api('calendar', 'v3')
    res = @client.execute(:api_method => calendar.events.get,
                          :parameters => {'calendarId' => 'primary','eventId' => eventId},
                          :headers => {'Content-Type' => 'application/json'})
    calendar_lists = []
    if res.status == 200
      calendar_lists = JSON.parse(res.body)
    end
    calendar_lists
  end

  def self.free_busy_resources(auth_hash, resource_params)
    gc_auth(auth_hash, nil)
    cal = @client.discovered_api('calendar', 'v3')
    resource_lists = get_resource_list
    # resourceが空の場合は終了
    return unless resource_lists.present?
    separated_resource_lists = resource_lists.each_slice(MAX_RESOURCE_SIZE).to_a
    free_busy_lists = []
    separated_resource_lists.each do |list|
      res = @client.execute(:api_method => cal.freebusy.query,
                            :body => JSON.dump(free_busy_params(list, resource_params)),
                            :headers => {'Content-Type' => 'application/json'})
      if res.status == 200
        results = JSON.parse(res.body)
        index = 0
        results['calendars'].map do |calendar|
          ids = {}
          ids['id'] = calendar[0]
          ids['name'] = list[index]['resourceName']
          # set availabilities
          if calendar[1]['busy'].present? || !list[index]['write_access']
            ids['available'] = 0
          else
            ids['available'] = 1
          end
          free_busy_lists << ids
          index +=1
        end
      end
    end
    free_busy_lists
  end

  def self.all_resources(auth_hash)
    gc_auth(auth_hash, nil)
    cal = @client.discovered_api('calendar', 'v3')
    resource_lists = get_resource_list
    # resourceが空の場合は終了
    return unless resource_lists.present?
    res = @client.execute(:api_method => cal.freebusy.query,
                    :body => JSON.dump(all_resources_params(resource_lists)),
                    :headers => {'Content-Type' => 'application/json'})
    all_resource_lists = []
    if res.status == 200
      results = JSON.parse(res.body)
      index = 0
      results['calendars'].map do |calendar|
        ids = {}
        ids['id'] = calendar[0]
        ids['name'] = resource_lists[index]['resourceName']
        ids['busy'] = calendar[1]['busy']
        all_resource_lists << ids
        index +=1
      end
    end
    all_resource_lists
  end

  def self.free_busy_availability_times(auth_hash, resource_params, host_uqids=nil, resource_ids=nil)
    gc_auth(auth_hash, nil)
    cal = @client.discovered_api('calendar', 'v3')
    resource_lists = get_resource_list(resource_ids)
    # resourceが空の場合は終了
    return unless resource_lists.present?

    resource_names = {}
    resource_lists.map do |resource|
      resource_names[resource['id']] = resource['resourceName']
    end

    separated_resource_lists = resource_lists.each_slice(MAX_RESOURCE_SIZE).to_a
    separated_resource_lists += get_employees_list(nil, employees_uqids=host_uqids)

    separated_resource_ids = []
    separated_resource_lists.map do |separated_resource|
      separated_resource_ids.push(separated_resource['id'])
    end
    print(separated_resource_ids)
    res = @client.execute(:api_method => cal.freebusy.query,
                          :body => JSON.dump(free_busy_params(separated_resource_ids, resource_params)),
                          :headers => {'Content-Type' => 'application/json'})

    resources = []
    resource_names.each do |key, value|
      resources.push(
          {
              id: key,
              name: value
          }
      )
    end

    result_schedules = {'availability_times' => nil, 'resources' => resources}
    if res.status == 200
      results = JSON.parse(res.body)
      one_hour_schedules = all_one_hour_schedules(resource_params)
      if results.has_key?('calendars')
        results['calendars'].map do |id, calendar|
          result_schedule = {}
          result_schedule['resource'] = {
              name: resource_names[id],
              id: id
          }
          result_schedule['time'] = []
          calendar[1]['busy'].each do |busy|
            start_date = Time.zone.parse(busy['start'])
            end_date = Time.zone.parse(busy['end'])
            one_hour_schedules.delete_if do |schedules|
              if (start_date.to_i..end_date.ago(1.minutes).to_i).include?(schedules['start'].to_i) || (start_date.since(1.minutes).to_i..end_date.to_i).include?(schedules['end'].to_i)
                true
              else
                result_schedule['time'].push(
                   {
                     "start": start_date,
                     "end": end_date
                   }
                )
                false
              end
            end
          end
        end
        result_schedules['availability_times'] = one_hour_schedules
      end
    end
    result_schedules
  end

  def self.gc_auth_with_code(code)
    # uri = URI.parse("https://www.googleapis.com/oauth2/v4/token")
    # http = Net::HTTP.new(uri.host, uri.port)

    # client_secrets = Google::APIClient::ClientSecrets.load(ENV['CLIENT_SECRETS_JSON'])
    # http.use_ssl = true
    # http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    # req = Net::HTTP::Post.new(uri.path)
    # req.set_form_data(set_form_data(client_secrets, code))

    # res = http.request(req)
    # res_body = JSON.parse(res.body)

    post_req_parser_init = PostReqParser.new("https://www.googleapis.com/oauth2/v4/token")
    res_body = post_req_parser_init.parse(REDIRECT_URI, code)
    client_secrets = post_req_parser_init.load_client_secrets
    
    if res_body["expires_in"] > 0 && res_body["access_token"].present? && res_body["refresh_token"].present?
      @client = Google::APIClient.new(:application_name => 'receptionist')
      @client.authorization = Signet::OAuth2::Client.new(
        token_credential_uri: 'https://accounts.google.com/o/oauth2/token',
        audience:             'https://accounts.google.com/o/oauth2/token',
        scope:                API_SCOPE,
        client_id:     client_secrets.client_id,
        client_secret: client_secrets.client_secret,
        refresh_token: res_body["refresh_token"],
        access_token: res_body["access_token"],
        expires_in: res_body["expires_in"]
      )
      @client.authorization
    else
      return nil
    end
  rescue
    return nil
  end

  def self.gc_auth(auth_hash, calendar_id)
    @client = Google::APIClient.new(:application_name => 'receptionist')
    @calendar_id  = calendar_id.presence || 'primary'
    if auth_hash
      @client.authorization = auth_hash
    else
      google_auth_init = GoogleAuthService.new(API_SCOPE, REDIRECT_URI)
      google_auth_init.oauth_url
    end
  end

  def self.set_form_data(secret, code)
    {'client_id' => secret.client_id, 'client_secret' => secret.client_secret, 'grant_type' => "authorization_code", 'access_type' => 'offline', 'code' => code, 'redirect_uri' => REDIRECT_URI}
  end

  def self.free_busy_params(resource_ids, resource_params)
    if resource_params.blank?
      return {}
    end
    start_time = resource_params['timeMin']
    # avoid google api bug
    end_time = resource_params[:timeMax]
    end_time = (Time.zone.parse(end_time) - 1.minute).strftime("%Y-%m-%dT%H:%M:%S%:z")
    {
      'timeMin' => start_time,
      'timeMax' => end_time,
      'items' => resource_ids,
    }
  end

  def self.all_resources_params(resource_ids)
    # その日のリソース一覧
    timeMin = Time.current.beginning_of_day.strftime("%Y-%m-%dT%H:%M:%S%:z")
    timeMax = Time.current.end_of_day.strftime("%Y-%m-%dT%H:%M:%S%:z")
    {
      'timeMin' => timeMin,
      'timeMax' => timeMax,
      'items' => resource_ids
    }
  end

  def self.all_one_hour_schedules(resource_params)
    start_time = Time.zone.parse(resource_params[:timeMin]).to_datetime
    end_time = Time.zone.parse(resource_params[:timeMax]).to_datetime

    # 30分ずつずらし、1時間のstart,endを取得する
    one_hour_schedules = []
    (start_time.to_i..end_time.to_i).step(30.minutes) do |date|
      if Time.at(date).since(1.hour) <= end_time
        one_hour_schedules.push({ "start" => Time.at(date), "end" => Time.at(date).since(1.hour)})
      end
    end
    one_hour_schedules
  end

end
