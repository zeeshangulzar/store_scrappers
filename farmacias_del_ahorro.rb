require 'pqsdk'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'byebug'


class FarmaciasDelAhorro

  STORE_URL = 'https://www.fahorro.com/storelocator/index/indexcms/'
  AJAX_URL = 'https://www.fahorro.com/storelocator/index/loadstore'
  MAP_URL = 'https://www.fahorro.com/storelocator/index/loadstore?type=map'
  LEAFLET_URL = 'http://www.fahorro.com/'


  def get_leaflet store_ids
    links = []
    page = Nokogiri::HTML(open(LEAFLET_URL))
    page.traverse do |el|
      links << [el[:src], el[:href]].grep(/\.(pdf)$/i)
    end
      links.flatten.each do |link|
      link = [LEAFLET_URL, link].join('/') unless link.start_with?('http')
      leaflet = PQSDK::Leaflet.find link
      if leaflet.nil?
        leaflet = PQSDK::Leaflet.new
        leaflet.name = "Leaflet"
        leaflet.start_date = leaflet.end_date =  Time.now.to_s
        leaflet.url = link
        leaflet.store_ids = store_ids
        leaflet.save
      end
    end
  end

  def get_stores
    all_stores = []
    html_response = Nokogiri::HTML(open(AJAX_URL))
    doc = JSON.parse(open(MAP_URL).read)
    stores_data = doc["stores"]
    stores_data.each do |store_data|
      store = {}
      store[:latitude] = store_data["latitude"]
      store[:longitude] = store_data["longtitude"]
      id = "#s_store-" + store_data["storelocator_id"]
      data = html_response.css(id)
      store[:name] = data.css('.info_popup .store_name').text.gsub("Ã\u0091", '')
      address = data.css('.info').css('.store_address').text.split('C.P. ')
      store[:address] = address.first.strip.chomp(",").strip.gsub("Ã\u0091", '').strip
      store[:zipcode] =  address.last
      store[:city] = data.css('.info_popup').children.last.text.split(",").first.gsub("Ã\u0091", '')
      all_stores << store
      puts "store_infos: " + store.inspect
    end
    all_stores
  end

  def update_store(stores)
    all_stores = []
    stores.each do |store|
      begin
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
        puts "Promoqui_infos: " + s.inspect
        s.save
        all_stores << s.id
      rescue => e
        p "*"*100
        p store
      end
    end
    all_stores
  end


  def run
    PQSDK::Token.reset!
    PQSDK::Settings.host = 'api.promoqui.eu'
    PQSDK::Settings.app_secret = '908d1df7449ead2d4241c5c29168b16e406ce795c867e86e86f69cfe887ae183'
    stores = get_stores
    store_ids = update_store(stores)
    get_leaflet(store_ids.uniq)
  end
end

a = FarmaciasDelAhorro.new
a.run
