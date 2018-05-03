class MicrosoftService
	attr_reader :current_api_employee

	CLIENT_ID = Rails.application.config.microsoft_client_id
	CLIENT_SECRET = Rails.application.config.microsoft_client_secret
	REDIRECT_URI = Rails.application.config.microsoft_redirect_uri
	SCOPES = [ 'offline_access','User.Read', 'Calendars.ReadWrite']
	MICROSOFT_AUTH_URL = "https://login.microsoftonline.com"
  MICROSOFT_API_URL = "https://graph.microsoft.com"
	
	def initialize(user)
		@current_api_employee = user
	end

	def token_expired?
		# token expiration depends upon when the employee logged in last time
		# and has an hour passed after his login ?
		update_time = current_api_employee.employee_microsoft.updated_at
		if update_time.day == Time.current.day && update_time.hour == Time.current.hour
			return false
		else
			return true
		end
	end

	def refresh_access_token
		url = "https://login.microsoftonline.com/common/oauth2/v2.0/token"
		auth_hash = current_api_employee.employee_microsoft.auth_hash
		post_req = PostReqParser.new(url)
		token = post_req.parse do |req, http|
			req.set_form_data({
	    	client_id: CLIENT_ID,
				scope: SCOPES.join(' '),
				refresh_token: auth_hash["refresh_token"],
				grant_type: 'refresh_token',
				client_secret: CLIENT_SECRET,
				redirect_uri: REDIRECT_URI
	    })
	    res = http.request(req)
	    JSON.parse(res.body)
		end
		raise 'Failed to get microsoft auth token' if token.key? "error"
		EmployeeMicrosoft.save_token current_api_employee,token
	end

	def save_appo_to_outlook appointment
			save_appointment appointment
	end

	def self.oauth_url
		"#{MICROSOFT_AUTH_URL}/common/oauth2/v2.0/authorize?client_id=#{CLIENT_ID}&response_type=code&redirect_uri=#{URI.encode(REDIRECT_URI)}&response_mode=query&scope=#{URI.encode(SCOPES.join(' '))}&state=#{SecureRandom.urlsafe_base64(nil, false)}&prompt=consent"
	end

	# a calendar group contains list of calendars
	def primary_calendar
		url = "#{MICROSOFT_API_URL}/v1.0/me/calendarGroups"
		get_req = GetReqParser.new url
		access_token = current_api_employee.employee_microsoft.auth_hash['access_token']
		resp = get_req.parse(access_token)
		resp["value"][0]["id"] #primary calendar is returned first
	end

	def fetch_users
		token_expired? ? refresh_access_token : nil
		url = "#{MICROSOFT_API_URL}/v1.0/users"
		access_token = current_api_employee.employee_microsoft.auth_hash['access_token']
		get_req = GetReqParser.new url
		resp = get_req.parse access_token
		raise "Could not fetch users from the microsoft api" if resp.key? "error"
		resp
	end

	def calendar_lists
		token_expired? ? refresh_access_token : nil
		url = "#{MICROSOFT_API_URL}/v1.0/me/calendarGroups/#{primary_calendar}/calendars"
		get_req = GetReqParser.new url
		access_token = current_api_employee.employee_microsoft.auth_hash['access_token']
		resp = get_req.parse(access_token)
	end

	def save_appointment appointment
		token_expired? ? refresh_access_token : nil
		url = "#{MICROSOFT_API_URL}/v1.0/me/calendar/events"
		appointment_req = PostReqParser.new url
		attendees = []
		appointment.hosts.each do |host|
			attendees <<  {
	                   "emailAddress": {
	                     "address": host.email
	                   },
	                   "type": "required"
	                 }
		end
	  appointment_resp = appointment_req.parse do |req, https|
	  	req['Content-Type'] = 'application/json'
		  req['Authorization'] = "Bearer #{current_api_employee.employee_microsoft.auth_hash['access_token']}"
		  req.body = {
	               "subject": "[RN#{appointment.code}]\s",
	               "body": {
	                "contentType": "HTML",
	                 "content": appointment.title
	               },
	               "start": {
	                   "dateTime": appointment.begin_at.strftime("%Y-%m-%dT%H:%M:%S%:z"),
	                   "timeZone": "Pacific Standard Time"
	               },
		              "end": {
		                   "dateTime": appointment.end_at.strftime("%Y-%m-%dT%H:%M:%S%:z"),
		                   "timeZone": "Pacific Standard Time"
		              },
	               "location":{
	                   "displayName": appointment.place
	                },
	                "attendees": attendees
	            }.to_json
		  res = JSON.parse(https.request(req).body)
	  end
	end

	def update_appo_in_outlook appointment
	 token_expired? ? refresh_access_token : nil
   uri = URI.parse("#{MICROSOFT_API_URL}/v1.0/me/events/#{appointment.eid}")
   https = Net::HTTP.new(uri.host, uri.port)
   https.use_ssl = true
   req = Net::HTTP::Patch.new(uri.path)
   attendees = []
	 appointment.hosts.each do |host|
			attendees <<  {
	                   "emailAddress": {
	                     "address": host.email
	                   },
	                   "type": "required"
	                 }
	 end
   req['Content-Type'] = 'application/json'
   req['Authorization'] = "Bearer #{current_api_employee.employee_microsoft.auth_hash['access_token']}"
   req.body = {
	               "subject": "[RN#{appointment.code}]\s",
	               "body": {
	                "contentType": "HTML",
	                 "content": appointment.title
	               },
	               "start": {
	                   "dateTime": appointment.begin_at.strftime("%Y-%m-%dT%H:%M:%S%:z"),
	                   "timeZone": "Pacific Standard Time"
	               },
		              "end": {
		                   "dateTime": appointment.end_at.strftime("%Y-%m-%dT%H:%M:%S%:z"),
		                   "timeZone": "Pacific Standard Time"
		              },
	               "location":{
	                   "displayName": appointment.place
	                },
	                "attendees": attendees
	            }.to_json
   res = JSON.parse(https.request(req).body)
	end

	def delete_appo_from_outlook eid
		token_expired? ? refresh_access_token : nil
		uri = URI.parse("#{MICROSOFT_API_URL}/v1.0/me/events/#{eid}")
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Delete.new(uri.path)
    req['Content-Type'] = 'application/json'
    req['Authorization'] = "Bearer #{current_api_employee.employee_microsoft.auth_hash['access_token']}"
    res = https.request(req)
	end
end
