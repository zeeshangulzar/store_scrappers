require 'pqsdk'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'byebug'

class SamClub

  STORE_URL = 'https://m.samsclub.com/locator'
  API_URL = 'https://m.samsclub.com/api/node/clubfinder/list?distance=100&nbrOfStores=20&singleLineAddr='
  LEAFLET_URL = 'https://www.samsclub.com/sams/pagedetails/content.jsp?pageName=one-day-event-catalog '


  # def get_leaflet(store_ids)
  #   p "*"*100
  #   p LEAFLET_URL
  #   byebug
  #   doc = Nokogiri::HTML(open(LEAFLET_URL))#, :allow_redirections => :all))
  #   pdf_links = doc.css('.container .row .col-md-4 a').map { |pdf| pdf.attr('href') }
  #   pdf_links.each do |pdf_url|
  #     leaflet = PQSDK::Leaflet.find pdf_url
  #     if leaflet.nil?
  #       leaflet = PQSDK::Leaflet.new
  #       leaflet.name = "Leaflet"
  #       leaflet.start_date = leaflet.end_date = Time.now.to_s
  #       leaflet.url = pdf_url
  #       leaflet.store_ids = store_ids
  #       leaflet.save
  #     end
  #   end
  # end

  def parse_hours(hours_data)
    weekdays = []
    if hours_data["monToFriHrs"].present?
      (0..4).each do |day|
        hours = {}
        hours[:weekday] = day
        hours[:open_am] = hours_data["monToFriHrs"]["startHr"]
        hours[:close_am] = hours_data["monToFriHrs"]["endHr"]
        weekdays << hours
      end
    end

    if hours_data["saturdayHrs"].present?
      hours = {}
      hours[:weekday] = 5
      hours[:open_am] = hours_data["saturdayHrs"]["startHr"]
      hours[:close_am] = hours_data["saturdayHrs"]["endHr"]
       weekdays << hours
    end

    if hours_data["sundayHrs"].present?
      hours = {}
      hours[:weekday] = 6
      hours[:open_am] = hours_data["sundayHrs"]["startHr"]
      hours[:close_am] = hours_data["sundayHrs"]["endHr"]
      weekdays << hours
    end
    weekdays
  end

  def get_stores(cities)
    all_stores = []
    count = 0
    cities.each do |city|
      count = count + 1
      begin
        doc = JSON.parse(open(API_URL + city.name).read)
        doc.each do |store_data|
          store = {}
          store[:name] = store_data["name"]
          store[:city] = city.name
          if store_data["address"].present?
            store[:address] = store_data["address"]["address1"]
            store[:zipcode] = store_data["address"]["postalCode"]
          end

          if store_data["geoPoint"].present?
            store[:latitude] = store_data["geoPoint"]["latitude"]
            store[:longitude] =  store_data["geoPoint"]["longitude"]
          end

          store[:phone] = store_data["phone"]
          store[:hours] = parse_hours(store_data["operationalHours"])
          puts "store_infos: " + store.inspect
          all_stores << store
        end
      rescue => e
        p "-"*100
        p e
        next
      end
      byebug
      break if count == 5
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
    PQSDK::Settings.host = 'c-api.ilikesales.com'
    # PQSDK::Settings.host = 'c-api.ilikesales.mx'
    cities = PQSDK::City.all
    PQSDK::Token.reset!
    PQSDK::Settings.host = 'api.promoqui.eu'
    PQSDK::Settings.app_secret = '54a7b5ef6480693c4684eeb7045647ef50ab421aaaad8173d9361176d2ffc042'
    stores = get_stores(cities)
    store_ids = update_store(stores)
    # store_ids = []
    # get_leaflet(store_ids.uniq)
  end
end

a = SamClub.new
a.run
