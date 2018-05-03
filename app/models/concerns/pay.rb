module Pay
  extend ActiveSupport::Concern

  ##################################################################
  # 社員数関係のmethods
  ##################################################################

  # 課金の実行
  def employee_charge(current_plan_id, new_plan_id)
    # previous_amount, new_amount, charge_amount = calculate_charge(current_plan_id, new_plan_id)
    # result = create_charge(charge_amount)
    self.update(ec_plan_id: new_plan_id)
    # PaymentMailer.upgrade(self, 'employee', current_plan_id, previous_amount, new_amount, charge_amount).deliver_later if result
    return nil
  end

  ##################################################################


  ##################################################################
  # タブレット数関係のmethods
  ##################################################################

  # 課金の実行
  def tablet_charge(current_plan_id, new_plan_id)
    # previous_amount, new_amount, charge_amount = calculate_charge(current_plan_id, new_plan_id)
    # result = create_charge(charge_amount)
    self.update(tc_plan_id: new_plan_id)
    # PaymentMailer.upgrade(self, 'tablet', current_plan_id, previous_amount, new_amount, charge_amount).deliver_later if result
    return nil
  end

  # プランの更新
  def update_tablet_plan
    # TODO: move to another class
    create_setting_app
    return nil
  end

  ##################################################################



  ##################################################################
  # トライアル期間終了時のmethods
  ##################################################################

  # トライアル期間終了時の課金メソッド
  def execute_subscription
    self.update(payment_type: "measured_price")
    return unless self.payjp_registered? # 課金対象でないのでスルー
    max_count = self.max_employee_count
    enterprise = self.id == 105 ? false : self.upgraded_plan? # インサイトさんのみstandard扱いに
    current_tablet_count = self.setting_apps.count

    result_status = []
    if max_count > 10 # プランの最大社員数が10人より多い(=課金対象)
      self.prorate_employee_subscription(max_count, enterprise)
      result_status.push('prorate_employee_subscription')
    end
    if current_tablet_count > 1 # 2台以上使っている(=課金対象)
      self.prorate_tablet_subscription(current_tablet_count)
      result_status.push('prorate_tablet_subscription')
    end
    self.update_plan_status(max_count, enterprise)
    PaymentMailer.trial_end(self).deliver_later
    return result_status
  rescue => e
    ErrorSlackNotifier.delay.payment_error(self, e, __method__)
  end

  # トライアル期間終了時用、日割りでの定期課金を作成
  def prorate_employee_subscription(max_employee_count, enterprise)
    new_plan_id = enterprise ? "ec-#{max_employee_count}-enterprise" : "ec-#{max_employee_count}"
    sub_id = create_prorate_sub(self.uid, new_plan_id)
    self.update(ec_sub_id: sub_id, ec_plan_id: new_plan_id)
  end

  # トライアル期間終了時用、日割りでの定期課金を作成
  def prorate_tablet_subscription(current_tablet_count)
    sub_id = create_prorate_sub(self.uid, "tc-#{current_tablet_count}")
    self.update(tc_sub_id: sub_id, tc_plan_id: "tc-#{current_tablet_count}")
  end
  ##################################################################

  # plan_statusを現在の状態を確認して更新する
  def update_plan_status(max_employee_count, enterprise)
    if enterprise
      self.upgrade_to_business
    elsif max_employee_count <= 10
      self.downgrade_to_free
    elsif self.plan_status != 'premium'
      self.upgrade_to_basic
    end
  end

  ##################################################################
  # 1日1回プラン変更チェック用のmethods
  ##################################################################

  # 1日1回プラン変更チェックのメソッド
  # この処理では定期課金IDは操作しない
  def execute_change_subscription
    # 課金対象でない
    unless self.payjp_registered?
      CompanySlackNotifier.delay.change_subscription_alert(self, "payment_type is measured_price. Don't registered payjp.", __method__)
      return nil
    end

    # トライアル期間中
    if self.trial_expired?
      CompanySlackNotifier.delay.change_subscription_alert(self, "During the trial period.", __method__)
      return nil
    end

    result_status = []

    enterprise = self.id == 105 ? false : self.upgraded_plan? # インサイトさんのみstandard扱いに
    max_count = self.max_employee_count
    if enterprise && max_count == 10
      max_count = 50
    end
    employee_status = check_employee_plan(self, enterprise, max_count)
    result_status.push(employee_status) if employee_status
    
    new_tablet_count = self.setting_apps.count
    tablet_status = check_tablet_plan(self, new_tablet_count)
    result_status.push(tablet_status) if tablet_status

    return result_status
  rescue => e
    ErrorSlackNotifier.delay.payment_error(self, e, __method__)
    p e
    return []
  end

  def check_employee_plan(company, enterprise, max_count)
    status = nil

    # 1. 現在の値の取得
    current_plan_id = company.ec_plan_id
    enterprise = self.id == 105 ? false : self.upgraded_plan? # インサイトさんのみstandard扱いに
    max_count = self.max_employee_count

    # 2. 課金対象の数値かチェック
    # if max_count > 10 || enterprise
    if max_count > 10
      # if enterprise && max_count == 10
      #   new_plan_id = "ec-50"
      # else
      new_plan_id = enterprise ? "ec-#{max_count}-enterprise" : "ec-#{max_count}"
      # end
      # 4. DB側のプラン(前日までのプラン)と現在のプランを比較
      if current_plan_id != new_plan_id
        # 5. それぞれの課金額を取得
        current_sub = company.current_employee_subscription
        current_amount = current_sub.present? ? current_sub[:plan][:amount] : 0 # 初めて課金対象になった場合はcurrent_subがemptyになる
        next_plan = plan_info(new_plan_id)
        next_amount = next_plan[:amount]

        # 6. 課金額を比較
        if next_amount > current_amount # 課金額が上がった
          # 7. 日割り課金 8. plan idの更新
          result = employee_charge(current_plan_id, new_plan_id)
          if result.blank?
            status = 'ec-upgrade'
          end
        elsif next_amount <= current_amount # 課金額が下がったorプランを先月のものに戻した
          # 8. plan idの更新
          company.update(ec_plan_id: new_plan_id)
          status = 'ec-downgrade'
        end
      end
    else
      if current_plan_id
        # 課金対象から課金対象外になった
        company.update(ec_plan_id: nil)
        status = 'ec-downgrade'
      end
    end
    status
  end

  def check_tablet_plan(company, new_tablet_count)
    status = nil

    new_plan_id = "tc-#{new_tablet_count}"
    current_plan_id = company.tc_plan_id
    # 2. 課金対象の数値かチェック
    if new_tablet_count > 1
      # 4. DB側のプラン(前日までのプラン)と現在のプランを比較
      if current_plan_id != new_plan_id
        # 5. 6. タブレットの場合は単純にタブレット数で比較できる
        current_tablet_count = current_plan_id.nil? ? 1 : current_plan_id.delete('tc-').to_i
        if new_tablet_count > current_tablet_count  # タブレットを増やした
          # 7. 日割り課金 8. plan idの更新
          result = company.tablet_charge(current_plan_id, new_plan_id)
          if result.blank?
            status = 'tc-upgrade'
          end
        else # タブレットを減らした
          # 8. plan idの更新
          company.update(tc_plan_id: new_plan_id)
          status = 'tc-downgrade'
        end
      end
    else
      if current_plan_id
        # 課金対象から課金対象外になった
        company.update(tc_plan_id: nil)
        status = 'tc-downgrade'
      end
    end
    status
  end


  ##################################################################
  # 決済日のmethods
  ##################################################################

  # 社員数決済前調整
  def employee_settlement
    # 課金対象でない
    unless self.payjp_registered?
      return 'PLAN_UNCHANGED', nil
    end

    # トライアル期間中
    if self.trial_expired?
      return 'PLAN_UNCHANGED', nil
    end

    # 1. 現在の値の取得
    enterprise = self.id == 105 ? false : self.upgraded_plan? # インサイトさんのみstandard扱いに
    max_count = self.max_employee_count

    # if max_count > 10 || enterprise
    if max_count > 10
      # if enterprise && max_count == 10
      #   new_plan_id = "ec-50"
      # else
      new_plan_id = enterprise ? "ec-#{max_count}-enterprise" : "ec-#{max_count}"
      # end
      current_sub_id = self.ec_sub_id
      if current_sub_id
        # 先月も課金している企業
        current_sub = self.current_employee_subscription
        if current_sub.present?
          if current_sub[:plan][:id] != new_plan_id
            # プランを変更した
            delete_sub(current_sub[:id])
            sub_id = create_sub(self.uid, new_plan_id)
            self.update(ec_sub_id: sub_id, ec_plan_id: new_plan_id)
            return 'PLAN_CHANGED', "%s -> %s" % [current_sub[:plan][:id], new_plan_id]
          else
            return 'PLAN_UNCHANGED', nil
          end
        else
          #　ここには通常ありえない
          ErrorSlackNotifier.delay.payment_error(self, 'ec_plan_id not found!', __method__)
          return 'PLAN_NOT_FOUND', nil
        end
      else
        # 先月は課金対象外だった企業
        sub_id = create_sub(self.uid, new_plan_id)
        self.update(ec_sub_id: sub_id, ec_plan_id: new_plan_id)
        return 'PLAN_CREATED', new_plan_id
      end
    else
      if self.ec_sub_id
        # 課金対象から課金対象外になった
        delete_sub(self.ec_sub_id)
        self.update(ec_sub_id: nil, ec_plan_id: nil)
        return 'PLAN_DELETED', nil
      else
        return 'PLAN_UNCHANGED', nil
      end
    end
  end

  # タブレット台数決済前調整
  def tablet_settlement
    # 課金対象でない
    unless self.payjp_registered?
      return 'PLAN_UNCHANGED', nil
    end

    # トライアル期間中
    if self.trial_expired?
      return 'PLAN_UNCHANGED', nil
    end

    # 1. 現在の値の取得
    current_tablet_count = self.setting_apps.count

    if current_tablet_count > 1
      new_plan_id = "tc-#{current_tablet_count}"
      current_tc_sub_id = self.tc_sub_id
      if current_tc_sub_id
        # 先月も課金している企業
        current_sub = self.current_tablet_subscription
        if current_sub.present?
          if current_sub[:plan][:id] != new_plan_id
            # プランを変更した
            delete_sub(current_sub[:id])
            sub_id = create_sub(self.uid, new_plan_id)
            self.update(tc_sub_id: sub_id, tc_plan_id: new_plan_id)
            return 'PLAN_CHANGED', "%s -> %s" % [current_sub[:plan][:id], new_plan_id]
          else
            return 'PLAN_UNCHANGED', nil
          end
        else
          #　ここには通常ありえない
          ErrorSlackNotifier.delay.payment_error(self, 'tc_plan_id not found!', __method__)
          return 'PLAN_NOT_FOUND', nil
        end
      else
        # 先月は課金対象外だった企業
        sub_id = create_sub(self.uid, new_plan_id)
        self.update(tc_sub_id: sub_id, tc_plan_id: new_plan_id)
        return 'PLAN_CREATED', new_plan_id
      end
    else
      if self.tc_sub_id
        # 課金対象から課金対象外になった
        delete_sub(self.tc_sub_id)
        self.update(tc_sub_id: nil, tc_plan_id: nil)
        return 'PLAN_DELETED', nil
      else
        return 'PLAN_UNCHANGED', nil
      end
    end
  end

  ##################################################################



  private

  # 日割りを有効にするsubscription。初回課金時に使用
  def create_prorate_sub(uid, plan)
    result = Payjp::Subscription.create(
      plan: plan,
      customer: uid,
      prorate: true,
      'metadata[company_name]': self.name
    )
    result['id']
  end

  # 日割りが有効でないsubscription。アップグレード時に使用
  def create_sub(uid, plan)
    result = Payjp::Subscription.create(
      plan: plan,
      customer: uid,
      'metadata[company_name]': self.name
    )
    result['id']
  end

  def delete_sub(sub_id)
    sub = Payjp::Subscription.retrieve(sub_id)
    sub.delete if sub
  end

  def cancel_sub(sub_id)
    sub = Payjp::Subscription.retrieve(sub_id)
    sub.cancel if sub
  end

  def calculate_charge(before_plan_id, new_plan_id)

    month_days = Date.new(Date.current.year, Date.current.month, -1).day
    diff_days = (Date.current.next_month.beginning_of_month - Date.current).to_i
    diff_days = diff_days > 0 ? diff_days : 1

    if before_plan_id.present?
      previous_plan = plan_info(before_plan_id)
      previous_amount = previous_plan[:amount]
      new_plan = plan_info(new_plan_id)
      new_amount = new_plan[:amount]
      charge_amount = (new_amount - previous_amount) * (diff_days.fdiv(month_days))
    else
      new_plan = plan_info(new_plan_id)
      new_amount = new_plan[:amount]
      charge_amount = new_amount * (diff_days.fdiv(month_days))
    end
    return previous_amount, new_amount, charge_amount.to_i
  end

  # アップグレード時の追加料金分の単発課金
  def create_charge(charge_amount)
    # スタンダードプランにダウンロードした後に社員を増やすと差額分がマイナスになる可能性がある
    if charge_amount > 0
      Payjp::Charge.create(
        amount: charge_amount,
        currency: 'jpy',
        customer: self.uid,
        'metadata[company_name]': self.name
      )
      return true
    else
      return false
    end
  end

  def plan_info(new_plan_id)
    Payjp::Plan.retrieve(new_plan_id)
  end

  # dupしたいが、uidがかぶるのでわざわざ新たなhashを自力で作る
  def create_setting_app
    setting_app = SettingApp.create!(new_setting_app_params)
    create_setting_custom(setting_app)
  end

  def new_setting_app_params
    new_setting_app = setting_apps.first
    new_params = {
      company_id: new_setting_app.company_id,
      tablet_uid: nil,
      tablet_location: new_setting_app.tablet_location,
      theme: new_setting_app.theme,
      logo_url: new_setting_app.logo_url,
      bg_rgb: new_setting_app.bg_rgb,
      bg_default: new_setting_app.bg_default,
      text: new_setting_app.text,
      text_en: new_setting_app.text_en,
      done_text: new_setting_app.done_text,
      done_text_en: new_setting_app.done_text_en,
      code: new_setting_app.code,
      search: new_setting_app.search,
      input_name: new_setting_app.input_name,
      input_company: new_setting_app.input_company,
      input_number_code: new_setting_app.input_number_code,
      input_number_search: new_setting_app.input_number_search,
      tel_error: new_setting_app.tel_error,
      monitoring: true,
      monitor_begin_at: Time.parse("0:00:00"),
      monitor_end_at: Time.parse("11:00:00")
    }
    new_params
  end

  #TODO 雑
  def create_setting_custom(setting_app)
    chats = [1, 2, 1, 2]
    actives = [true, false, true, true]
    recordings = [true, true, true, true]
    input_names = [true, true, true, false]
    input_companies = [false, true, true, false]
    input_numbers = [false, true, true, false]
    texts = ['面接の方はこちら', 'カスタムボタン2', '総合受付', '配達業者さま専用']
    texts_en = ['Employment interview', 'option button2', 'All other queries(general reception)', 'For courier']
    1.upto(4) do |n|
      setting_custom = SettingCustom.create(
        setting_app_id: setting_app.id,
        chat_id: chats[n-1],
        active: actives[n-1],
        recording: recordings[n-1],
        input_name: input_names[n-1],
        input_company: input_companies[n-1],
        input_number: input_numbers[n-1],
        text: texts[n-1],
        text_en: texts_en[n-1],
        mention_in: ''
      )
      mentions = []
      num = setting_custom.chat.name == 'Chatwork' ? 2 : 1
      1.upto(num) do |c|
        cm = CustomMention.create(
          mention_to: '',
          setting_custom_id: setting_custom.id
        )
        mentions.push(cm)
      end
      setting_custom.custom_mentions << mentions
    end
  end
end