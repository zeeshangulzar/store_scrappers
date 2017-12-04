require 'pqsdk'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'byebug'
require 'geocoder'

Geocoder.configure(
  timeout: 5,
  lookup:  :google,
  api_key: 'AIzaSyCYkLXVWq41-1RYrWxBvnUCm-qXcE4FJYo',
  units:   :mi
  )

class Dpam

  STORE_URL = 'http://en.dpam.com/storelocator/index/loadstore/'

  def get_hours(page)
    hours = []
    hours_data = page.css('.opening-hours .time li')
    hours_data.each_with_index do |day, index|
      day_hour = {}
      day_hour[:weekday] = index
      if day.text.downcase == 'closed'
        day_hour[:closed] = true
      else
        time = day.text.split("to")
        day_hour [:open_am] = time.first.gsub("from ", "").strip
        day_hour[:close_am] = time.last.strip
      end
      hours << day_hour
    end
    hours
  end

  def get_coordinates(store, page)
    store[:latitude] = page.css('script').map {|s| s.content.scan(/var setLat = parseFloat(.*)'\)/)}.flatten.first.gsub("('", '')
    store[:longitude] = page.css('script').map {|s| s.content.scan(/var setLon = parseFloat(.*)'\)/)}.flatten.first.gsub("('", '')
    store
  end

  def get_stores
    all_stores = []
    doc = Nokogiri::HTML(open(STORE_URL))
    stores_url = doc.css('.store_detail a').map {|store| store.attr('href')}.select {|s| s != 'javascript:void(0);'}
    stores_url.each do |store_url|
    # stores_url[305..333].each do |store_url|
      page = Nokogiri::HTML(open(store_url))
      country = page.css('.store-locator-view-detail span')[1].elements.last.text
      next unless country  == "Italy"
      store = {}
      store[:name] = page.css('.store-name').text
      store[:hours] =  get_hours(page)
      store = get_coordinates(store, page)

      address = page.css('.store-locator-view-detail span').children
      store[:address] =  address[2].text
      sub_address = address[4].text.split(",")
      store[:zipcode] =  sub_address.first
      store[:city] = sub_address.last.split(' ').first
      phone = address[9].children[1].text.gsub('.', '')
      unless phone.include?('@dpamnet')
        store[:phone] = phone
      end
      puts "Store_infos: " + store.inspect
      puts "Store_url:" + store_url
      all_stores << store
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
        s.opening_hours = store[:hours]
        s.phone = store[:phone]
        s.phone
      end
      puts "Promoqui_infos: " + s.inspect
      s.save
    end
  end


  def run
    PQSDK::Token.reset!
    PQSDK::Settings.host = 'api.promoqui.eu'
    PQSDK::Settings.app_secret = '2ba836efa25ad208b0663dc604b14368d9ade47a67ebc47cb1ec97b509896f50'
    stores = get_stores
    update_store(stores)
  end
end

a = Dpam.new
a.run
