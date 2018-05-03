# == Schema Information
#
# Table name: visitors
#
#  id                :integer          not null, primary key
#  uid               :string(255)
#  notifier_type     :integer
#  company_id        :integer
#  employee_id       :integer
#  appointment_id    :integer
#  setting_custom_id :integer
#  setting_app_id    :integer
#  display           :boolean
#  name              :string(255)
#  company_name      :string(255)
#  number            :integer
#  email             :string(255)
#  phone_no          :string(255)
#  custom_label      :string(255)
#  custom_label_en   :string(255)
#  tablet_location   :string(255)
#  visited_at        :datetime
#  checked_out_at    :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#

class Visitor < ActiveRecord::Base
  include Uid
  attr_accessor :visited, :unvisited

  SUNDAY = 'sunday'
  MONDAY = 'monday'
  TUESDAY = 'tuesday'
  WEDNESDAY = 'wednesday'
  THURSDAY = 'thursday'
  FRIDAY = 'friday'
  SATURDAY = 'saturday'
  DATE_FORMAT = '%-m月%-d日'

  belongs_to :appointment
  belongs_to :company
  belongs_to :employee
  belongs_to :setting_app

  before_validation :prepare_visited_at, if: :visited
  before_validation :nullify_visited_at, if: :unvisited

  unless Rails.env.test?
    after_create :delete_cache
  end
  before_create :set_default_checked_out_at

  scope :visible, -> {
    where(display: true)
  }
  scope :invisible, -> {
    where(display: false)
  }
  scope :visited, -> {
    where.not(visited_at: nil)
  }
  scope :order_by_desc, -> {
    order(visited_at: "DESC")
  }
  scope :with_company, -> {
    where.not(company_name: nil)
  }
  scope :search_by_company_name, -> (company_name) {
    where('company_name like ?', "%#{company_name}%")
  }

  #validates :name, presence: true
  validates_datetime :visited_at, allow_nil: true

  # action_message :all

  LOCK_AFTER_TIME = 5.minutes
  def locked?
    visited_at && visited_at < Time.current - LOCK_AFTER_TIME
  end

  def self.monthly_count(visitors, types)
    # Rails.cache.fetch(cache_key('monthly_count'), expires_in: 1.hour) do
      nums = []
      days = ((Date.current - 1.month)..Date.current).to_a
      types.each do |type|
        type_nums = []
        days.each do |day|
          visitors_per_day = visitors.select{|v| v.visited_at.to_date == day}
          type_nums << filter_by_btn_type(visitors_per_day, type).size
        end
        nums << type_nums
      end
      nums
    # end
  end

  def self.monthly_days
    ((Date.current - 1.month)..Date.current).to_a.map { |day| day.to_time.strftime("#{DATE_FORMAT}") }
  end

  def self.top_num_employees
    Rails.cache.fetch(cache_key('top_num_employees'), expires_in: 1.hour) do
      rank_result = []
      ids = group(:employee_id).order('count(visitors.employee_id) desc').limit(5).pluck(:employee_id)
      return rank_result if ids.empty? || ids.all? {|id| id.nil?}
      employees = Employee.where(id: ids).order("field(id, #{ids.compact.join(',')})")
      employees.each do |employee|
        result_detail = {}
        result_detail[:name] = employee.name
        result_detail[:num] = employee.visitors.size
        rank_result << result_detail
      end
      rank_result
    end
  end

  def self.visited_companies
    Rails.cache.fetch(cache_key('visited_companies'), expires_in: 1.hour) do
      visited_companies = []
      visitors = with_company.limit(5)
      if visitors.present?
        visitors.each do |visitor|
          result_detail = {}
          result_detail[:company_name] = visitor.company_name
          result_detail[:in_charge] = Employee.find_by_id(visitor.employee_id).try(:name)
          visited_companies << result_detail
        end
      end
      visited_companies
    end
  end

  def self.to_csv
    csv_data = CSV.generate do |csv|
      csv << csv_column_names
      all.each do |visitor|
        csv << visitor.csv_column_values
      end
    end
    csv_data.encode!("utf-16")
  end

  def self.csv_column_names
    %w(日時 ボタン種別 ゲスト会社名 ゲスト名前 ホスト側担当者 来客数 退館時間)
  end

  def csv_column_values
    date = visited_at.strftime('%Y年%m月%d日 %H:%M')
    host = employee.try(:name)
    kind = custom_label || '担当者検索'
    kind = "受付コード: #{appointment.code}" if appointment.try(:code)
    checked_out_time = nil
    if checked_out_at.present?
      checked_out_time = checked_out_at.strftime('%Y年%m月%d日 %H:%M')
    end
    [date, kind, company_name, name, host, number, checked_out_time]
  end

  def delete_cache
    reg_key = "#{Thread.current[:company].try(:id)}*visitor*"
    Rails.cache.delete_matched(reg_key)
  end

  def self.cache_key(method, ops=nil)
    [
      Thread.current[:company].id,
      "visitor##{method}",
      ops
    ].join('/')
  end

  private

  def prepare_visited_at
    self.visited_at = Time.current
  end

  def nullify_visited_at
    self.visited_at = nil unless locked?
  end

  def set_default_checked_out_at
    self.checked_out_at = created_at + 1.hour
  end

  def self.filter_by_btn_type(visitors_per_day, type)
    if type == "担当者検索"
      visitors_per_day.select{|v| v[:appointment_id] == nil && v[:custom_label] == nil}
    elsif type == "受付コード"
      visitors_per_day.select{|v| v[:appointment_id] != nil}
    else
      visitors_per_day.select{|v| v[:setting_custom_id] == type}
    end
  end

end
