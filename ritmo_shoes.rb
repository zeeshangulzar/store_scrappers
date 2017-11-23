require 'pqsdk'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'byebug'

class RitmoShoes

  STORE_URL = 'http://www.ritmoshoes.it/punti-vendita'
  LEAFLET_URL = 'http://www.ritmoshoes.it/collezioni'
  URL = 'http://www.ritmoshoes.it/'

  WEEKDAYS = { "Lunedì" => 0, "Martedì" => 1, "Mercoledì" => 2, "Giovedì" => 3, "Venerdì" => 4, "Sabato" => 5, "Domenica" => 6 }



  def get_hours(store_data, store)
    hours = store_data.text.scan(/orari:\r\n(.*)mappa/m).flatten.first
    if hours.nil?
      hours = store_data.text.scan(/Orari:\r\n(.*)mappa/m).flatten.first
    end
    store[:hours] = hours.try(:strip)
    store
  end

  def format_hours
  end

  def parse_hours(day, daily_hours)
    morning_hours = day.children[3].text.split(" ")
    if morning_hours.size == 1 && morning_hours[0] == 'closed'
      daily_hours[:closed] = true
      return daily_hours
    end
    daily_hours[:open_am] = morning_hours[0]
    daily_hours[:close_am] = morning_hours[1]
    if day.children[6]
      evening_hours = day.children[6].text.split(" ")
      daily_hours[:open_pm] = evening_hours[0]
      daily_hours[:close_pm] = evening_hours[1]
    end
    daily_hours
  end

  def get_leaflet(store_ids)
    doc = Nokogiri::HTML(open(LEAFLET_URL))
    leaflet_images = doc.css('#iso-container a').map { |l| [URL, l.attr('href').gsub('./', '')].join }

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

  def get_lat_lon(store)
    doc = Nokogiri::HTML(open(store[:origin]))
    scripts = doc.css('script')
    store[:latitude] = scripts.map {|s| s.content.scan(/lat:(.*),/)}.flatten.first.strip
    store[:longitude] = scripts.map {|s| s.content.scan(/lon:(.*),/)}.flatten.first.strip
    store
  end

  def get_stores
    all_stores = []
    doc = Nokogiri::HTML(open(STORE_URL))
    stores_data = doc.css('.pdv')
    count = 1
    stores_data.each do |store_data|
      p count
      count = count + 1;
      store = {}
      store = get_hours(store_data, store)
      store[:origin] = URL + store_data.css('a').attr('href').text
      store = get_lat_lon(store)
      store[:name] = store_data.css('.title').text
      address = store_data.children[2].text.strip
      if address.downcase.start_with?('presso')
        if store_data.children[4].text.strip.downcase.start_with?('via')
          store[:address] =  [address, store_data.children[4].text.strip].join(' ')
          location = store_data.children[6].text.split(' ')
          store[:zipcode] = location.first
          location.pop
          location.shift
          store[:city] = location.join(' ')
          store[:phone] = store_data.children[8].text.split('tel.').last.strip
        else
          if store_data.children[4].text =~/\d/
            store[:zipcode] = store_data.children[4].text.to_i
            location = store_data.children[4].text.split
            location.shift
            province = location.last.gsub(/[^a-zA-Z]/, "")
            if province.size == 2
              location.pop
              store[:city] = location.join(' ').split(",").last.strip
            else
              store[:city] = location.last
            end

            store[:address] =  address
            store[:phone] = store_data.children[6].text.split('tel.').last.strip
          else
            store[:zipcode] = store_data.children[6].text.to_i
            location = store_data.children[6].text.split
            location.pop
            location.shift
            store[:city] = location.join(' ')
            store[:address] = [address, store_data.children[4].text.strip].join(' ')
            store[:phone] = store_data.children[8].text.split('tel.').last.strip
          end
        end
      else
        store[:address] = address
        location = store_data.children[4].text.split(' ')
        store[:zipcode] = location.first
        location.pop
        location.shift
        store[:city] = location.join(' ')
        store[:phone] = store_data.children[6].text.split('tel.').last.strip
      end
      puts "Store_infos: " + store.inspect
      puts store[:hours]
      all_stores << store
    end
     all_stores
  end

  def update_stores(stores)
    all_stores = []
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
      s.opening_hours = store[:hours]
      puts "Store_infos: " + s.inspect
      s.save
      all_stores << s.id
    end
    all_stores
  end

  def run
    # PQSDK::Token.reset!
    # PQSDK::Settings.host = 'api.promoqui.eu'
    # PQSDK::Settings.app_secret = '7879f182452d03c4e198a807817c531fb38287f85fa5ff7e36223f375fe20f44'
    stores = get_stores
    # store_ids = update_stores(stores)
    # get_leaflet store_ids
  end
end

a = RitmoShoes.new
a.run
