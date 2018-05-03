module Mslack
  require 'net/https'
  extend ActiveSupport::Concern

  def get_group_id
    uri = URI.parse("https://slack.com/api/usergroups.list")
    http = Net::HTTP.new(uri.host, uri.port)

    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    req = Net::HTTP::Post.new(uri.path)
    token = self.token.include?('https') ? self.slack_api_token : self.token
    req.set_form_data(set_form_data(token))

    res = http.request(req)
    res_body = JSON.parse(res.body)
    if res_body["usergroups"].count > 0
      usergroup_lists = []
      res_body['usergroups'].map do |user_group|
        ids = {}
        ids['name'] = user_group['handle']
        ids['id'] = user_group['id']
        usergroup_lists << ids
      end
      usergroup_lists
    else
      return nil
    end
  rescue
    return nil
  end

  protected

  def set_form_data(token)
    {'token' => token}
  end
end
