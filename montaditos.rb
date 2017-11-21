require 'pqsdk'
require 'json'
require 'nokogiri'
require 'open-uri'

class Montaditos

  STORE_URL = 'https://italy.100montaditos.com/dove-siamo/'
  LEAFLET_URL = 'https://italy.100montaditos.com/promozioni/'

  def get_stores
    doc = Nokogiri::HTML(open(STORE_URL))
    stores = doc.css('script').map {|s| s.content.scan(/locals_list = (.*);/)}
    stores_data = JSON.parse(stores.flatten.first)
    allStores = []
    stores_data.each do |store_data|
      store = {}
      store[:name] = store_data["title"]
      store[:address] = store_data["address"]
      store[:zipcode] = store_data["postal_code"]
      store[:phone_number] = store_data["phone_number"]
      store[:latitude] = store_data["latitude"]
      store[:longitude] = store_data["longitude"]
      store[:city] = store_data["city_tax"]
      allStores << store
    end
     allStores
  end

  def update_store(stores)
    store_ids = []
    stores.each do |store|
      s = PQSDK::Store.find(store[:address], store[:zipcode])
      if s.nil?
        s = PQSDK::Store.new
        s.name = store[:name]
        s.city = store[:city] == '' ? 'DEFAULT' : store[:city]
        s.address = store[:address]
        s.origin = STORE_URL
        s.latitude = store[:latitude]
        s.longitude = store[:longitude]
        s.zipcode = store[:zipcode]
        s.phone = store[:phone_number]
      end
      puts "Store_infos: " + s.inspect
      s.save
      store_ids << s.id
    end
    store_ids
  end

  def get_leaflet(store_ids)
    doc = Nokogiri::HTML(open(LEAFLET_URL))
    leaflet_images = doc.css('.bloque-imagen img').map { |l| l.attr('src') }

    leaflet = PQSDK::Leaflet.find LEAFLET_URL
    if leaflet.nil?
      leaflet = PQSDK::Leaflet.new
      leaflet.name = "Leaflet"
      leaflet.start_date = leaflet.end_date = Time.now.to_s
      leaflet.image_urls = leaflet_images
      leaflet.url = LEAFLET_URL
      leaflet.store_ids = store_ids
      leaflet.save
    end
  end

  def run
    PQSDK::Token.reset!

    #Debug
    PQSDK::Settings.host = 'api.promoqui.eu'
    PQSDK::Settings.app_secret = 'f69e55ea82c336a14aa583dec84de050abca49455b177260052785f9d3abf461'
    stores = get_stores
    store_ids = update_store(stores)
    leaflet =  get_leaflet store_ids
  end
end

a = Montaditos.new
a.run
