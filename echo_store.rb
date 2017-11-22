require 'pqsdk'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'byebug'

class EchoStore

  STORE_URL = 'https://www.ecostore.it/app/themes/pn-theme/models/services/get-all-locations.php'
  STORE_DETAIL = 'https://www.ecostore.it/store?id='
  ORIGIN = 'https://www.ecostore.it/store-locator/'

  WEEKDAYS = { "LUN" => 0, "MAR" => 1, "MER" => 2, "GIO" => 3, "VEN" => 4, "SAB" => 5, "DOM" => 6 }

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
    if morning_hours.size == 1 && morning_hours[0] == 'closed'
      daily_hours[:closed] = true
      return daily_hours
    end
    daily_hours[:open_am] = morning_hours[0]
    daily_hours[:close_am] = morning_hours[1]
    if day.children[6]
      evening_hours = day.children[6].text.split(" ")
      daily_hours[:open_pm] = evening_hours[0]
      daily_hours[:close_pm] = evening_hours[1]
    end
    daily_hours
  end

  def parse_city(address)
    city = address.split(',')[-2].tr("0-9", "").strip
    city_array = city.split(" ")
    if city_array.last.size == 2
      city_array.pop
    end
    city_array.join(' ')
  end

  def get_stores
    all_stores = []
    doc = Nokogiri::HTML(open(STORE_URL))
    stores_data = JSON.parse(doc)
    stores_data.each do |store_data|
      store = {}
      store[:name] = store_data["store_name"]
      store[:address] = store_data["formatted_address_loc"].split(",").first
      store[:zipcode] = store_data["formatted_address_loc"].split(',')[-2].gsub(/[^\d]/, '')
      store[:latitude] = store_data["lat"]
      store[:longitude] = store_data["lng"]
      store[:city] = parse_city(store_data["formatted_address_loc"])
      if store_data["status"] == "1"
        detail_url = STORE_DETAIL + store_data["store_code"].to_s
        store_detail = Nokogiri::HTML(open(detail_url))
        store[:phone_number] = store_detail.css('.single-store__rec a').text
        store[:hours] = get_hours store_detail
      end
      puts "Store_infos: " + store.inspect
      all_stores << store
    end
     all_stores
  end

  def update_stores(stores)
    stores.each do |store|
      s = PQSDK::Store.find(store[:address], store[:zipcode])
      if s.nil?
        s = PQSDK::Store.new
        s.name = store[:name]
        s.city = store[:city]
        s.address = store[:address]
        s.origin = ORIGIN
        s.latitude = store[:latitude]
        s.longitude = store[:longitude]
        s.zipcode = store[:zipcode]
        s.phone = store[:phone_number]
      end
      s.opening_hours = store[:hours]
      puts "Store_infos: " + s.inspect
      s.save
    end
  end

  def run
    PQSDK::Token.reset!
    PQSDK::Settings.host = 'api.promoqui.eu'
    PQSDK::Settings.app_secret = '6ff7d0a40b3f0021504e5aea15bbed51a13f484979d7fd2a27d0167545b877ca'
    stores = get_stores
    update_stores(stores)
  end
end

a = EchoStore.new
a.run
