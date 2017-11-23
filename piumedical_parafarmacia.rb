require 'pqsdk'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'byebug'
require 'geocoder'

class PiuMedicalParafarmacia

  STORE_URL = 'http://www.piumedical.it/punti_vendita.asp'
  LEAFLET_URL = 'http://www.piumedical.it/offerte_volantino.asp'
  LEAFLET_IMAGE_URL = 'https://image.isu.pub/171106093109-d3055575fcfc345fbb9d768207eaf063/jpg/'

  def get_leaflet store_ids
    leaflet_images = []
    (1..8).each do |page|
      page_number = ['page_', page, '.jpg'].join
      leaflet_images << LEAFLET_IMAGE_URL + page_number
    end

    leaflet = PQSDK::Leaflet.find LEAFLET_URL
    if leaflet.nil?
      leaflet = PQSDK::Leaflet.new
      leaflet.name = "Leaflet"
      leaflet.start_date = leaflet.end_date =  Time.now.to_s
      leaflet.url = LEAFLET_URL
      leaflet.image_urls = leaflet_images
      leaflet.store_ids = store_ids
      leaflet.save
    end
  end

  def get_stores
    all_stores = []
    doc = Nokogiri::HTML(open(STORE_URL))
    stores_data = doc.css('.citta')
    stores_data.each do |store_data|
      store = {}
      store[:origin] = STORE_URL + store_data.attr('href')
      page = Nokogiri::HTML(open(store[:origin]))

      store[:name] = page.css('.parafarmacia h3').text
      store[:phone] = page.css('.fa-phone').last.next.text
      store[:email] = page.css('.fa-at').last.next.text

      location = page.css('.fa-map-marker').last.next.text

      coordinates = Geocoder.search(location)
      store[:latitude] = coordinates[0].try(:latitude)
      store[:longitude] = coordinates[0].try(:longitude)

      location = location.split(",")
      store[:zipcode] = location.last.gsub(/[^\d]/, '')
      store[:city] = location.last.scan(/\((.*)\)/).flatten.first
      location.pop
      store[:address] = location.join.strip
      all_stores << store
      puts "Store_infos: " + store.inspect
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
        s.origin = store[:origin]
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

  def run
    PQSDK::Token.reset!
    PQSDK::Settings.host = 'api.promoqui.eu'
    PQSDK::Settings.app_secret = '79392ae4270b29d3212b129cd0ef95c4b9268579c7410b9b5b8f8650bec4f6cd'

    stores = get_stores
    store_ids = update_stores(stores)
    get_leaflet store_ids
  end
end

a = PiuMedicalParafarmacia.new
a.run
