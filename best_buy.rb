require 'pqsdk'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'byebug'
require 'geocoder'

DAYS = [4, 5, 6, 0,1 ,2 ,3]

Geocoder.configure(
  timeout: 5,
  lookup:  :google,
  api_key: 'AIzaSyCYkLXVWq41-1RYrWxBvnUCm-qXcE4FJYo',
  units:   :mi
  )

class Bestbuy

  STORE_URL = 'http://www.bestbuy.com.mx/storelocator/'
  API_URL = 'http://www.bestbuy.com.mx/storelocator/api/'
  LEAFLET_URL = 'http://www.bestbuy.com.mx/catalogo-semanal-bestbuy'
  LEAFLET_URL_NEW = 'http://www.bestbuy.com.mx/c/catalogo-semanal-bestbuy/s61'


  def get_leaflet(store_ids)
    p "*"*100
    p LEAFLET_URL
    byebug
    doc = Nokogiri::HTML(open(LEAFLET_URL))#, :allow_redirections => :all))
    pdf_links = doc.css('.container .row .col-md-4 a').map { |pdf| pdf.attr('href') }
    pdf_links.each do |pdf_url|
      leaflet = PQSDK::Leaflet.find pdf_url
      if leaflet.nil?
        leaflet = PQSDK::Leaflet.new
        leaflet.name = "Leaflet"
        leaflet.start_date = leaflet.end_date = Time.now.to_s
        leaflet.url = pdf_url
        leaflet.store_ids = store_ids
        leaflet.save
      end
    end
  end

  def parse_hours(hours_data)
    weekdays = []
    hours_data.each_with_index do |hour, index|
      hours = {}
      hours[:weekday] = DAYS[index]
      hours[:open_am] = hour["timeOpen"]
      hours[:close_am] = hour["timeClosed"]
      weekdays << hours
    end
    weekdays
  end

  def get_stores(cities)
    all_stores = []
    cities.each do |city|
      zipcode = Geocoder.search([city.latitude, city.longitude]).first.try(:postal_code)
      next unless zipcode

      if zipcode.size < 5
        (5 - zipcode.size..1).each do |i|
          zipcode += "0"
        end
      end

      begin
        doc = JSON.parse(open(API_URL + zipcode).read)
        doc["data"]["stores"].each do |store_data|
          store = {}
          store[:name] = store_data["name"]
          store[:city] = city.name
          store[:address] = store_data["addr1"]
          store[:latitude] = store_data["latitude"]
          store[:longitude] =  store_data["longitude"]
          store[:zipcode] = store_data["postalCode"]
          store[:phone] = store_data["phone"]
          store[:hours] = parse_hours(store_data["hours"])
          puts "store_infos: " + store.inspect
          all_stores << store
        end
      rescue => e
        p "-"*100
        p e
        next
      end
    end
    all_stores
  end

  def update_store(stores)
    store_ids = []
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
          s.phone = store[:phone]
          s.opening_hours = store[:hours]
        end
        puts "Promoqui_infos: " + s.inspect
        s.save
        store_ids << s.id
      rescue => e
        p "-"*100
        p s
        p e
      end
    end
    store_ids
  end

  def run
    PQSDK::Token.reset!
    # PQSDK::Settings.host = 'c-api.ilikesales.com'
    PQSDK::Settings.host = 'c-api.ilikesales.mx'
    cities = PQSDK::City.all
    PQSDK::Token.reset!
    PQSDK::Settings.host = 'api.promoqui.eu'
    PQSDK::Settings.app_secret = '79582c0202042a6b8cf29c4ea5e950fa50f3870489dfbe5de0ff862d216d8ab4'
    stores = get_stores(cities)
    store_ids = update_store(stores)
    # store_ids = []
    # get_leaflet(store_ids.uniq)
  end
end

a = Bestbuy.new
a.run
