require 'pqsdk'

class Crawler::Uk::OneStopUk < Crawler::Base

  def get_hours hoursJson

    hoursJson = hoursJson.gsub("\r",'').gsub("\n",'').gsub("&lt;",'<').gsub("&gt;",'>').gsub(/Midnight|midnight/,'11:59pm').gsub("<br/>",'').gsub(/24hr|24hrs|24 hrs/,'00:00am - 11:59pm').split('pm').join('pm<br>') + 'pm'
    hours = hoursJson.split('<br>')
    ret = []
    return ret if hours.count == 0
    hours.each do |hour|
      p "hour_data: "+hour
      if hour.include? 'Monday'
        oh = {}
        oh[:weekday] = 0
        oh[:open_am] = Time.parse(hour.split('-')[0]).strftime("%H:%M")
        oh[:close_pm] = Time.parse(hour.split('-')[1]).strftime("%H:%M")
        ret << oh
      end
      if hour.include? 'Tuesday'
        oh = {}
        oh[:weekday] = 1
        oh[:open_am] = Time.parse(hour.split('-')[0]).strftime("%H:%M")
        oh[:close_pm] = Time.parse(hour.split('-')[1]).strftime("%H:%M")
        ret << oh
      end
      if hour.include? 'Wednesday'
        oh = {}
        oh[:weekday] = 2
        oh[:open_am] = Time.parse(hour.split('-')[0]).strftime("%H:%M")
        oh[:close_pm] = Time.parse(hour.split('-')[1]).strftime("%H:%M")
        ret << oh
      end
      if hour.include? 'Thursday'
        oh = {}
        oh[:weekday] = 3
        oh[:open_am] = Time.parse(hour.split('-')[0]).strftime("%H:%M")
        oh[:close_pm] = Time.parse(hour.split('-')[1]).strftime("%H:%M")
        ret << oh
      end
      if hour.include? 'Friday'
        oh = {}
        oh[:weekday] = 4
        oh[:open_am] = Time.parse(hour.split('-')[0]).strftime("%H:%M")
        oh[:close_pm] = Time.parse(hour.split('-')[1]).strftime("%H:%M")
        ret << oh
      end
      if hour.include? 'Saturday'
        oh = {}
        oh[:weekday] = 5
        oh[:open_am] = Time.parse(hour.split('-')[0]).strftime("%H:%M")
        oh[:close_pm] = Time.parse(hour.split('-')[1]).strftime("%H:%M")
        ret << oh
      end
      if hour.include? 'Sunday'
        oh = {}
        oh[:weekday] = 6
        oh[:open_am] = Time.parse(hour.split('-')[0]).strftime("%H:%M")
        oh[:close_pm] = Time.parse(hour.split('-')[1]).strftime("%H:%M")
        ret << oh
      end

    end
    ret.uniq{|x| x[:weekday]}
  end

  def get_leaflet url, storeIds
    pdf_url = url
    pdf_name = "Leaflet"
    pdf_start = Time.now.to_s
    pdf_end = Time.now.to_s

    puts "Download from --> #{pdf_url}"
    leaflet = PQSDK::Leaflet.find pdf_url
    if leaflet.nil?
      leaflet = PQSDK::Leaflet.new
      leaflet.name = pdf_name
      leaflet.start_date = pdf_start
      leaflet.end_date = pdf_end
      leaflet.url = pdf_url
      leaflet.store_ids = storeIds
      leaflet.save
    end
  end


  def get_stores
    allStores = []
    City.confirmed.each do |city|
      lat = city.latitude
      long = city.longitude

      url = "http://www.onestop.co.uk/sl/index.php"
      uri = URI.parse(url)
      sleep(1)
      response = Net::HTTP.post_form(uri, {"ajax" => 1, "action" => "get_nearby_stores", "distance" => "100000", "lat" => "#{lat}", "lng" => "#{long}"})
      data = JSON.parse(response.body[7..-1])

      data['stores'].each do |store_data|
        store = {}

        store[:store_name] = store_data['name'].strip

        store_address_city_zip = store_data['address'].split(',')
        split_count = store_data['address'].split(',').count

        if split_count == 4
          store[:store_zip] = store_address_city_zip[3]
          store[:store_address] = "#{store_address_city_zip[0]} #{store_address_city_zip[1]}"
          store[:store_city] = store_address_city_zip[1] #1
        elsif split_count == 5
          store[:store_zip] = store_address_city_zip[4]
          store[:store_address] = "#{store_address_city_zip[0]} #{store_address_city_zip[1]}"
          store[:store_city] = store_address_city_zip[1] #1
        elsif split_count == 6
          store[:store_zip] = store_address_city_zip[5]
          store[:store_address] = "#{store_address_city_zip[0]} #{store_address_city_zip[1]}"
          store[:store_city] = store_address_city_zip[1] #1
        elsif split_count == 3
          store[:store_zip] = store_address_city_zip[2]
          store[:store_address] = store_address_city_zip[0]
          store[:store_city] = store_address_city_zip[1]
        else
          store[:store_zip] = '0'
          store[:store_address] = store_address_city_zip
          store[:store_city] = 'Manual Check'
          p "Need Exception for this --> #{split_count}| #{store_address_city_zip};"
        end
        latitude = store_data['lat'].match(/([0-9\,\.\s]+)/)
        longitude = store_data['lng'].match(/([0-9\,\.\s\-]+)/)

        store[:store_lat] = (latitude.nil? or !(latitude[1].to_i > -90 and latitude[1].to_i < 90)) ? 0 : latitude[1]
        store[:store_lng] = (longitude.nil? or !(longitude[1].to_i > -180 and longitude[1].to_i < 180)) ? 0 : longitude[1]
        store[:store_phone] = if store_data['telephone'].nil? then '' else store_data['telephone'] end
        store[:hours] = get_hours store_data['description']

        allStores << store
      end
    end

    allStores.uniq{|s| [s[:store_address], s[:store_zip]]}
  end

  def update_stores stores
    allStores = []
    stores.each do |store|

      if !PQSDK::City.find(store[:store_city].strip).nil? and PQSDK::City.find(store[:store_city].strip).state == 'confirmed'
        store_city = store[:store_city].strip
      elsif !PQSDK::City.find(store[:store_name].gsub('One Stop', '').strip).nil? and PQSDK::City.find(store[:store_name].gsub('One Stop','').strip).state == 'confirmed'
        store_city = store[:store_name].gsub('One Stop','').strip
      else
        store_city = store[:store_city].strip
      end

      s = PQSDK::Store.find(store[:store_address], store[:store_zip])
      if s.nil?
        s = PQSDK::Store.new
        s.name = store[:store_name]
        s.city = store_city.split(' ').each{|x| x.capitalize!}.join(' ')
        s.address = store[:store_address]
        s.origin = "http://www.onestop.co.uk/sl/index.php"
        s.latitude = store[:store_lat]
        s.longitude = store[:store_lng]
        s.zipcode = store[:store_zip]
        s.phone = store[:store_phone]
      end
      s.opening_hours = store[:hours]
      @report.info << "Store_infos: " + s.inspect
      s.save
      allStores << s.id
    end
    allStores.uniq
  end

  def run
    PQSDK::Token.reset!

    Debug
    PQSDK::Settings.host = 'api.promoqui.eu'
    PQSDK::Settings.app_secret = 'SECRET_TOKEN_GIVEN_FROM_US'


    leaflet_url = 'http://www.onestop.co.uk/documents/offers_leaflet.pdf'
    stores = get_stores
    storeIds = update_stores stores
    leaflet = get_leaflet leaflet_url, storeIds.uniq

  end

end
