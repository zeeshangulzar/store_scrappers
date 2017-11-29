require 'pqsdk'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'byebug'
require 'geocoder'

Geocoder.configure(
  timeout: 5,
  lookup:  :google,
  api_key: "AIzaSyBRXZRZ2D2sB0lqQhBDsm619tV471Y5zFw",
  units:   :mi
  )

class ProfumeriaPinalli

  STORE_URL = 'https://www.pinalli.it/punti-vendita/'
  ROOT_URL = 'https://www.pinalli.it'
  NAME = 'Profumeria Pinalli'

  def get_stores
    all_stores = []
    doc = Nokogiri::HTML(open(STORE_URL))
    stores_data = doc.css('.store-geo-list li')
    count = 0
    stores_data.each do |store_data|
      count = count + 1
      store = {}
      store[:name] = NAME
      store[:origin] = ROOT_URL + store_data.children.attr('href').text
      store[:address] = store_data.css('strong').last.next.text

      page = Nokogiri::HTML(open(store[:origin]))
      store[:phone] = page.css('.list-check li strong').last.next.text

      scripts = page.css('script').map {|s| s.content.scan(/var companies =(.*)/)}.flatten.first.split(",")
      store[:latitude] = scripts[2].strip
      store[:longitude] = scripts[3].strip
      location = Geocoder.search([store[:latitude], store[:longitude]]).first
      store[:zipcode] = location.try(:postal_code) || '00000'
      store[:city] = location.try(:city) || 'Default'
      all_stores << store
      puts "Store_infos: " + store.inspect
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
        s.origin = store[:origin]
        s.latitude = store[:latitude]
        s.longitude = store[:longitude]
        s.zipcode = store[:zipcode]
        s.phone = store[:phone]
      end
      puts "Store_infos: " + s.inspect
      s.save
    end
  end

  def run
    PQSDK::Token.reset!
    PQSDK::Settings.host = 'api.promoqui.eu'
    PQSDK::Settings.app_secret = '1904fbed9987ee6cd5653d558f8ad9e8ce281f94bc01a44b50adc64fbc95d612'
    stores = get_stores
    update_stores(stores)
  end
end

a = ProfumeriaPinalli.new
a.run
