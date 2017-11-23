require 'pqsdk'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'geocoder'
require 'byebug'

class CArt

  STORE_URL = 'https://www.c-art.it/negozi/'
  LEAFLET_URL = 'https://www.c-art.it/promozioni/'

  def get_leaflet store_ids
    doc = Nokogiri::HTML(open(LEAFLET_URL))
    url = doc.css('.content a')[1].attr('href')
    leaflet = PQSDK::Leaflet.find url
    if leaflet.nil?
      leaflet = PQSDK::Leaflet.new
      leaflet.name = "Leaflet"
      leaflet.start_date = leaflet.end_date =  Time.now.to_s
      leaflet.url = url
      leaflet.store_ids = store_ids
      leaflet.save
    end
  end

  def get_stores
    all_stores = []
    doc = Nokogiri::HTML(open(STORE_URL))
    stores_data = doc.css('.list-stores li')
    stores_data.each do |store_data|
      store = {}
      next if store_data.attr('id') == "empty-row"
      store[:name] = store_data.attr('data-name').gsub(/<\/?[^>]*>/, " ")
      store[:address] = store_data.attr('data-address')
      store[:city] = store_data.attr('data-city')
      store[:longitude] = store_data.attr('data-lon')
      store[:latitude] = store_data.attr('data-lat')
      store[:phone] = store_data.attr('data-phone')
      store[:zipcode] = get_zipcode(store)
      all_stores << store
    end
    all_stores
  end

  def update_stores(stores)
    store_ids = []
    stores.each do |store|
      s = PQSDK::Store.find(store[:address], store[:zipcode])
      if s.nil?
        s = PQSDK::Store.new
        s.name = store[:name]
        s.city = store[:city]
        s.address = store[:address]
        s.origin = STORE_URL
        s.latitude = store[:latitude]
        s.longitude = store[:longitude]
        s.zipcode = store[:zipcode]
        s.phone = store[:phone]
      end
      puts "Store_infos: " + s.inspect
      s.save
      store_ids << s.id
    end
    store_ids
  end

  def get_zipcode(store)
    location = Geocoder.search([store[:latitude], store[:longitude]]).first
    location.try(:postal_code) || '00000'
  end

  def run
    PQSDK::Token.reset!
    PQSDK::Settings.host = 'api.promoqui.eu'
    PQSDK::Settings.app_secret = '80766da5680cacdc862a3e65c82aa556cd2b3230d0c0f7b4968903f3b2df46a9'

    stores = get_stores
    store_ids = update_stores(stores)
    get_leaflet store_ids
  end
end

a = CArt.new
a.run
