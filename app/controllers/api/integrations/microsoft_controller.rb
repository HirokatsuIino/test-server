class Api::Integrations::MicrosoftController < ApplicationController
	before_action :authenticate_api_employee! unless Rails.env.development?
	before_action :prepare_company, only: [:sync_users]

	CLIENT_ID = ENV['MICROSOFT_CLIENT_ID']
	CLIENT_SECRET = ENV['MICROSOFT_CLIENT_SECRET']
	REDIRECT_URI = Rails.application.config.microsoft_redirect_uri
	SCOPES = [ 'offline_access','User.Read', 'Calendars.ReadWrite']
MICROSOFT_AUTH_URL = "https://login.microsoftonline.com"
 MICROSOFT_API_URL = "https://graph.microsoft.com"

	def auth
		url = MicrosoftService.oauth_url
		render json: {oauth_url: url}
	end

	def token
		url = "#{MICROSOFT_AUTH_URL}/common/oauth2/v2.0/token"
		post_req = PostReqParser.new(url)
		token = post_req.parse do |req, http|
			req.set_form_data({
	    	client_id: CLIENT_ID,
				scope: SCOPES.join(" "),
				code: params[:code],
				redirect_uri: REDIRECT_URI,
				grant_type: 'authorization_code',
				client_secret: CLIENT_SECRET
	    })
	    res = http.request(req)
	    JSON.parse(res.body)
		end
		raise 'Failed to get microsoft auth token' if token.key? "error"
		EmployeeMicrosoft.save_token current_api_employee,token
		render json: {access_token: token["access_token"]}
	end

	def sync_users
		microsoft = MicrosoftService.new current_api_employee
		users = microsoft.fetch_users
		save_users users
		render json: {success: true}
	end

	def calendar_list
		render json: MicrosoftService.new(current_api_employee).calendar_lists["value"]
	end

	private

	def save_users users
		users['value'].each do |user|
			employee = Employee.find_by email: user['userPrincipalName']
			if employee
				employee.update_attributes!(name: user['displayName'], company_id: @company.id, first_name: user['givenName'], last_name: user['surname'])
			else
				Employee.create!(email: user['userPrincipalName'], name: user['displayName'], company_id: @company.id, first_name: user['givenName'], last_name: user['surname'], password: Devise.friendly_token[0,10])
			end
		end
	end
end