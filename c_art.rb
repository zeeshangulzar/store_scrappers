require 'pqsdk'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'byebug'

class CArt

  STORE_URL = 'https://www.c-art.it/negozi/'
  LEAFLET_URL = 'https://www.c-art.it/promozioni/ '

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
      puts "Store_infos: " + store.inspect
      p "*"*100
      all_stores << store
    end
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
    PQSDK::Settings.app_secret = '80766da5680cacdc862a3e65c82aa556cd2b3230d0c0f7b4968903f3b2df46a9'
    stores = get_stores
    # update_stores(stores)
  end
end

a = CArt.new
a.run
