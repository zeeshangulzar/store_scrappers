require 'pqsdk'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'byebug'

class GameAthletics

  STORE_URL = 'http://www.game7athletics.com/contatti'

  def get_stores
    all_stores = []
    doc = Nokogiri::HTML(open(STORE_URL))
    map_url = doc.css('iframe').attr('src').text
    map = Nokogiri::HTML(open(map_url))

    data = map.css('script').map {|s| s.content.scan(/_pageData = \"(.*)/)}.flatten.first
    results = JSON.parse(data[0..-4].gsub(/\r/," ").gsub(/\\n/," ").delete('\\\\\\')).last
    stores_data =  results[6].last[12].last[13].first

    stores_data.each do |store_data|
      store = {}
      coords = store_data[1].flatten
      store[:latitude] = coords.first
      store[:longitude] = coords.last
      address = store_data[5].flatten
      if address[0] == 'Negozio'
        store[:name] = address[1]
        store[:address] = address[5]
        store[:city] = address[11]
        store[:zipcode] = address[8]
      else
        store[:name] = "Game 7 Athletics"
        store[:address] = address[3]
        store[:city] = address[9]
        store[:zipcode] = address[6]
      end
      all_stores << store
      puts "Store_infos: " + store[:address].inspect
    end
     all_stores
  end

  def update_store(stores)
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
      end
      puts "Store_infos: " + s.inspect
      s.save
    end
  end


  def run
    PQSDK::Token.reset!
    PQSDK::Settings.host = 'api.promoqui.eu'
    PQSDK::Settings.app_secret = 'ad8e202fd358489fea4bf7a59e8f8f0438831f82050511f2ef070dcc24bbe229'
    stores = get_stores
    update_store(stores)
  end
end

a = GameAthletics.new
a.run
