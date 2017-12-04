require 'pqsdk'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'byebug'

class PromoClub
  STORE_URL = 'http://www.promoclub.it/dove_siamo.php'
  WEEKDAYS = { "LUNEDI'" => 0, "Martedì" => 1, "Mercoledì" => 2, "Giovedì" => 3, "Venerdì" => 4, "SABATO" => 5, "DOMENICA" => 6 }

  def get_hours(hours_string)
    hours = []
    hours_data = hours_string.text.split("\r\n")
    hours_data.each do |data|
      if data.start_with?("LUNEDI'") || data.start_with?('DOMENICA')
        data = [data, hours_data[1]].join(' ') unless data.include?('dalle')
        data_array = data.split('-')
        start_day = data_array[0].strip
        unless start_day.include?("dalle")
          end_string = data_array[1].split
          end_day = end_string.first.strip
          (WEEKDAYS[start_day]..WEEKDAYS[end_day]).each do |day|
            hours_data = {}
            end_string[4] = end_string[4].gsub!(".", ':') if end_string[4].include?(".")
            end_string[2] = end_string[2].gsub!(".", ':') if end_string[2].include?(".")
            hours_data[:weekday] = day
            hours_data[:open_am] = end_string[2]
            hours_data[:close_am] = end_string[4]
            hours << hours_data
          end
        else
          start_data = start_day.split
            hours_data = {}
            start_data[4] = start_data[4].gsub!(".", ':') if start_data[4].include?(".")
            start_data[2] = start_data[2].gsub!(".", ':') if start_data[2].include?(".")
            hours_data[:weekday] = WEEKDAYS[start_data[0]]
            hours_data[:open_am] = start_data[2]
            hours_data[:close_am] = start_data[4]
            hours << hours_data
        end
      end
    end
    hours
  end

  def get_stores
    all_stores = []
    doc = Nokogiri::HTML(open(STORE_URL))
    doc_data  = doc.css('.pointsItem')
    coordinates = doc.css('script').map {|s| s.content.scan(/var points = (.*)var  content /m)}.flatten.first.gsub("\r\n", '')
    coordinates = coordinates[1..-3].strip[0..-3].strip.split("},")
    coordinates_values = coordinates.map {|c| c[1..-1].gsub('lat:', '').gsub('lng:', '').split(",") }
    doc_data.each_with_index do |store_data, index|
      store = {}
      store[:name] = store_data.css('.pointsItemTitle').text.gsub("\r\n", " ").strip
      details = store_data.css('.century')
      store[:hours] = get_hours(details.last.children)
      store_detail = details.first.children
      store[:address] = store_detail[0].text.gsub("\r\n", " ").strip
      address = store_detail.last.text.split(' ')
      address.pop
      store[:zipcode] = address.shift
      store[:city] = address.join(' ')
      unless coordinates_values[index].nil?
        store[:latitude] = coordinates_values[index][0]
        store[:longitude] = coordinates_values[index][1]
      end
      puts "Store infos: " + store.inspect
      all_stores << store
    end
    all_stores
  end

  def update_store(stores)
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
        s.opening_hours = store[:hours]
      end
      puts "Promoqui_infos: " + s.inspect
      s.save
      store_ids << s.id
    end
    store_ids
  end

  def run
    PQSDK::Token.reset!
    PQSDK::Settings.host = 'api.promoqui.eu'
    PQSDK::Settings.app_secret = '49efba684814433cd2ccb94b92ec0b470dd7e06be10a2d7a17f3f76efeb68211'
    stores = get_stores
    store_ids = update_store(stores)
  end
end

a = PromoClub.new
a.run
