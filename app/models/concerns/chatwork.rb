module Chatwork
  require 'open-uri'
  extend ActiveSupport::Concern

  def get_account_id(cw_id, mention_in=nil)
    token = self.company.setting_chats.find_by(chat_id: Chat.find_by(name: "Chatwork").id).token
    if token
      mention_in ? room_id = mention_in : room_id = self.mention_in
      begin
        res = open("https://api.chatwork.com/v2/rooms/#{room_id}/members",
                   "X-ChatWorkToken" => token)
        code, message = res.status

        if code == '200'
          results = ActiveSupport::JSON.decode res.read
          account_id = 0
          results.map { |result|
            if result["chatwork_id"] == cw_id
              account_id = result["account_id"]
              break
            else
              account_id = nil
            end
          }
          return account_id
        else
        end
      rescue => e
        logger.error(e)
        return account_id = nil
      end
    else
      account_id = nil
    end
  end

  # Get specific member's cw_id and cw_account_id in mention_in
  def get_ids(cw_id, mention_in=nil)
    token = self.company.setting_chats.find_by(chat_id: Chat.find_by(name: "Chatwork").id).token
    return response_failure unless token.present?
    mention_in ? room_id = mention_in : room_id = self.mention_in
    begin
      res = open("https://api.chatwork.com/v2/rooms/#{room_id}/members",
                 "X-ChatWorkToken" => token)
      code, message = res.status

      return response_failure unless code == '200'
      results = ActiveSupport::JSON.decode res.read
      response = { 'ok': false }
      results.each do |result|
        if result["chatwork_id"] == cw_id || result["account_id"] == cw_id.to_i
          response[:ok] = true
          response[:cw_id] = result['chatwork_id']
          response[:cw_account_id] = result['account_id']
          break
        end
      end
      response[:ok] ? response : response_failure
    rescue => e
      logger.error(e)
      return response_failure
    end
  end

  def get_cw_update_type(employee, mention_in, update_params)
    return false if !self.active || update_params[:icon_uri].present?
    new_mention_in = employee.mention_ins.find_by(chat_id: 2).try(:mention_in)
    # compare old and new value
    room_id = mention_in ? mention_in != new_mention_in : false
    main_id = employee.try(:cw_id) != update_params[:cw_id] # TODO: use employee_mentions table
    sub_id = employee.try(:cw_id_sub) != update_params[:cw_id_sub] # TODO: use employee_mentions table
    if main_id || sub_id || room_id
      return "both" if (main_id && sub_id) || room_id
      return "main" if main_id || !sub_id
      return "sub"  if !main_id || sub_id
    else
      false
    end
  end

  def update_cw_ids(cw_update_type, cw_mention_in, update_params)
    case cw_update_type
    when "both"
      ids = [:cw_id, :cw_id_sub]
    when "main"
      ids = [:cw_id]
    when "sub"
      ids = [:cw_id_sub]
    end
    attributes = update_params.clone
    failure = false
    mention_in = self.mention_in
    if cw_mention_in.present? && !cw_mention_in[:mention_in].blank?
      mention_in = cw_mention_in[:mention_in]
    end
    ids.each do |id|
      if attributes[id].blank?
        # in case of deleting sub account
        if id.to_s.include?("sub")
          attributes[:cw_account_id_sub] = nil
        end
      else
        cw_response = self.get_ids(attributes[id], mention_in)
        if cw_response[:ok]
          attributes[id] = cw_response[:cw_id]
          if id.to_s.include?("sub")
            attributes[:cw_account_id_sub] = cw_response[:cw_account_id]
          else
            attributes[:cw_account_id] = cw_response[:cw_account_id]
          end
        else
          failure = true
        end
      end
    end
    failure ? false : attributes
  end

  private

  def response_failure
    { 'ok': false }
  end

end
