require 'json'
require 'nokogiri'
require 'open-uri'
require 'byebug'

class EchoStore

  STORE_URL = 'https://www.ecostore.it/app/themes/pn-theme/models/services/get-all-locations.php'
  STORE_DETAIL = 'https://www.ecostore.it/store?id='
  WEEKDAYS = { "LUN" => 0, "MAR" => 1, "MER" => 2, "GIO" => 3, "VEN" => 4, "SAB" => 5, "DOM" => 6 }

  def get_stores
    all_stores = []
    doc = Nokogiri::HTML(open(STORE_URL))
    stores_data = JSON.parse(doc)
    stores_data.each do |store_data|
      store = {}
      store[:name] = store_data["store_name"]
      store[:address] = store_data["formatted_address_loc"]
      store[:zipcode] = store_data["formatted_address_loc"].split(',')[-2].gsub(/[^\d]/, '')
      store[:latitude] = store_data["lat"]
      store[:longitude] = store_data["lng"]
      store[:city] = store_data["formatted_address_loc"].split(',')[-2].tr("0-9", "").strip

      detail_url = STORE_DETAIL + store_data["store_code"].to_s
      store_detail = Nokogiri::HTML(open(detail_url))
      store[:phone_number] = store_detail.css('.single-store__rec a').text
      store[:hours] = get_hours store_detail
      all_stores << store
    end
     all_stores
  end

  def get_hours(store)
    hours_data = []
    hours_table = store.css('.single-store__table-list li')
    hours_table.each do |day|
      day_name = day.children[0].text
      p "hour_data: "+ day.text
      daily_hours = {}
      daily_hours[:weekday] = WEEKDAYS[day_name]
      hours_data << parse_hours(day, daily_hours)
    end
    hours_data
  end

  def parse_hours(day, daily_hours)
    morning_hours = day.children[3].text.split(" ")
    return daily_hours if morning_hours.size == 1 && morning_hours[0] == 'closed'
    daily_hours[:open_morning] = morning_hours[0]
    daily_hours[:close_morning] = morning_hours[1]
    if day.children[6]
      evening_hours = day.children[6].text.split(" ")
      daily_hours[:open_evening] = evening_hours[0]
      daily_hours[:close_evening] = evening_hours[1]
    end
    daily_hours
  end



  def run
    # PQSDK::Token.reset!
    # PQSDK::Settings.host = 'api.promoqui.eu'
    # PQSDK::Settings.app_secret = '1904fbed9987ee6cd5653d558f8ad9e8ce281f94bc01a44b50adc64fbc95d612'
    stores = get_stores
  end
end

a = EchoStore.new
a.run
