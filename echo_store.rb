require 'json'
require 'nokogiri'
require 'open-uri'
require 'byebug'

class EchoStore

  STORE_URL = 'https://www.ecostore.it/app/themes/pn-theme/models/services/get-all-locations.php'
  STORE_DETAIL = 'https://www.ecostore.it/store?id='

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
      byebug
      store[:hours] = get_hours store_detail
      all_stores << store
    end
     all_stores
  end

  def get_hours(store)
    byebug
   hours_table = store.css('.single-store__table-list')
  end


  def run
    # PQSDK::Token.reset!
    # PQSDK::Settings.host = 'api.promoqui.eu'
    # PQSDK::Settings.app_secret = '1904fbed9987ee6cd5653d558f8ad9e8ce281f94bc01a44b50adc64fbc95d612'
    stores = get_stores
    p "*"*100
    stores.each do |s| p s[:city] end
  end
end

a = EchoStore.new
a.run
