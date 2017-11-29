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
  NBSP = Nokogiri::HTML("&nbsp;").text


  def get_hours(store_data)
    weekdays = store_data.text.scan(/orari:\r\n(.*)mappa/m).flatten.first.try(:strip)
    weekdays = store_data.text.scan(/Orari:\r\n(.*)mappa/m).flatten.first.try(:strip) if weekdays.nil? || weekdays.strip == ""
    if weekdays.nil? || weekdays.strip == ""
      child = 9
      last_child = store_data.children.index(store_data.css('a').first)
      while child<last_child && !weekdays.include?("da")
        weekdays = store_data.children[child].text if weekdays.strip == ""
        child += 1
      end
    end
    weekdays = weekdays.gsub!("\r", ' ') if weekdays.include?("\r")
    weekdays = weekdays.gsub!("*", ' ') if weekdays.include?("*")
    weekdays = weekdays.gsub!("dalle", ' ') if weekdays.include?("dalle")
    weekdays = weekdays.gsub!("alle", '-') if weekdays.include?("alle")
    weekdays = weekdays.gsub!(": ", ' ') if weekdays.include?(": ")
    weekdays = weekdays.split("\n")
    weekdays
  end

  def add_slot(week_count, start_day, end_day, week)
    start_day[4] = start_day[4].gsub!(".", ':') if start_day[4].include?(".")
    start_day[6] = start_day[6].gsub!(".", ':') if start_day[6].include?(".")
    if week_count == 2
      end_day[0] = end_day[0].gsub!(".", ':') if end_day[0].include?(".")
      end_day[2] = end_day[2].gsub!(".", ':') if end_day[2].include?(".")
      return {
        weekday: week,
        open_am: start_day[4],
        close_am: start_day[6],
        open_pm: end_day[0],
        close_pm: end_day[2]
      }
    else
      return {
        weekday: week,
        open_am: start_day[4],
        close_pm: start_day[6]
      }
    end
  end

  def split_day_time(weekday)
    day_time = weekday.gsub(NBSP,' ').split(" ")
    if day_time.last.include?("-")
     time = day_time.last.split("-")
     day_time[day_time.size-1] = time.first
     day_time += ["-", time.last]
    end
    day_time
  end

  def format_hours(store_data)
    weekdays = get_hours(store_data)
    hours = []
    weekdays.each do |weekday|
      unless weekday.strip.gsub(NBSP,'') == ""
        if weekday.include?("/")
          weekday = weekday.split("/")
          start_day = split_day_time(weekday[0])
          end_day = split_day_time(weekday[1])
          week_count = weekday.count
        else
          start_day = weekday.gsub(NBSP,' ').split(" ")
          week_count = 1
        end

        if start_day.count == 7
          WEEKDAYS[start_day[1]]..(WEEKDAYS[start_day[3]]+1).times do |week|
            hours.push(add_slot(week_count, start_day, end_day, week))
          end
        else
          start_day[0] = "Domenica" if start_day[0] == "Dom"
          start_day[1] = start_day[1].gsub!(".", ':') if start_day[1].include?(".")
          start_day[3] = start_day[3].gsub!(".", ':') if start_day[3].include?(".")
          hours.push({
            weekday: WEEKDAYS[start_day[0]],
            open_am: start_day[1],
            close_pm: start_day[3]
          })
        end
      end
    end
    hours
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
      store = {}
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
      store[:hours] = format_hours(store_data)
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
    PQSDK::Token.reset!
    PQSDK::Settings.host = 'api.promoqui.eu'
    PQSDK::Settings.app_secret = '7879f182452d03c4e198a807817c531fb38287f85fa5ff7e36223f375fe20f44'
    stores = get_stores
    store_ids = update_stores(stores)
    get_leaflet store_ids
  end
end

a = RitmoShoes.new
a.run
