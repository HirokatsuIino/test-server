class GoogleAuthService
	attr_reader :scope, :redirect_uri

	def initialize(scope, redirect_uri)
		@scope = scope
		@redirect_uri = redirect_uri
	end

	def oauth_url
		client_secrets = Google::APIClient::ClientSecrets.load(ENV['CLIENT_SECRETS_JSON'])
    auth_client = client_secrets.to_authorization
    auth_client.update!(
     	:scope => scope,
      :redirect_uri => redirect_uri)
    auth_client.authorization_uri(:approval_prompt => "force").to_s
	end
end
