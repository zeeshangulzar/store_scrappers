require 'pqsdk'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'byebug'
require 'geocoder'

Geocoder.configure(
  timeout: 5,
  lookup:  :google,
  api_key: 'AIzaSyCYkLXVWq41-1RYrWxBvnUCm-qXcE4FJYo',
  units:   :mi
  )

class Superama

  STORE_URL = 'https://www.superama.com.mx/informacion/directorio-de-tiendas'
  STATE_URL = 'https://www.superama.com.mx/informacion/ObtenerDirectorioLocalidades'
  LOCATION_URL = 'https://www.superama.com.mx/informacion/ObtenerDatosTiendas'
  LEAFLET_URL = 'https://www.superama.com.mx'


  def get_hours(hours)
    hours_data = []
    (0..6).each do |day|
      daily_hours = {}
      daily_hours[:weekday] =  day
      if hours.downcase.start_with?('lunes')
        h = hours.downcase.gsub('lunes a domingo de ', '').split('a')
        if  h.size == 1 && h[0].split(' ').first == '24'
          daily_hours[:open_am] = '00:00'
          daily_hours[:close_pm] = "23:59"
        else
          daily_hours[:open_am] = h.first
          daily_hours[:close_am] = h.last.split(' ').first
        end
      else
        data = hours.downcase.split(' a ')
        if  data.size == 1 && data[0].split(' ').first == '24'
          daily_hours[:open_am] = '00:00'
          daily_hours[:close_pm] = "23:59"
        else
          return if data.size == 1
          daily_hours[:open_am] = data[0]
          daily_hours[:close_am] = data[1].split(' ').first
        end
      end
      hours_data << daily_hours
    end
    hours_data
  end

  def get_leaflet store_ids
    links = []
    page = Nokogiri::HTML(open(LEAFLET_URL))
    page.traverse do |el|
      links << [el[:src], el[:href]].grep(/\.(pdf)$/i)
    end

    page.css('.MargeBox').each do |entry|
      if entry.css('.tilemas').text.include?("Folleto")
        inner_page = entry.children[1].attr('href')
        if inner_page.present?
          new_leaflet = [LEAFLET_URL, inner_page].join('/')
          inner_page = Nokogiri::HTML(open(new_leaflet))
          inner_page.traverse do |el|
            links << [el[:src], el[:href]].grep(/\.(pdf)$/i)
          end
        end
      end
    end

    links.flatten.uniq.each do |link|
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
    doc = Nokogiri::HTML(open(STORE_URL)).css('#directorioEstados option')
    states = doc.map {|o| o.attr('value')}
    states.each do |state|
      params = {'estadoId' => state}
      response = Net::HTTP.post_form(URI.parse(STATE_URL), params)
      if response.code == '200' && response.message == 'OK'
        cities = JSON.parse(response.body)
        next if cities.blank?
        cities.each do |city|
          params = {'estadoId' => state, 'localidadId' => city["LocalidadId"]}
          data_response = Net::HTTP.post_form(URI.parse(LOCATION_URL), params)
          if data_response.code == '200' && data_response.message == 'OK'
            stores_data = JSON.parse(data_response.body)
            next if stores_data.blank?
            stores_data.each do |store_data|
              store = {}
              store[:name] = store_data["Nombre"]
              store[:zipcode] = store_data["CP"]
              store[:phone] = store_data["Telefono"]
              store[:address] = store_data["Direccion"].to_s + ' ' + store_data["Colonia"].to_s
              location = Geocoder.search(store[:address])[0]
              store[:city] = location.try(:city) || city["Descripcion"]
              store[:hours] = get_hours(store_data["Horario"])
              if store_data["LatSpan"] != "0" && store_data["LonSpan"] != "0"
                store[:latitude] = store_data["LatSpan"]
                store[:longitude] = store_data["LonSpan"]
              else
                store[:latitude] = location.try(:latitude)
                store[:longitude] = location.try(:longitude)
              end
              puts "store_infos: " + store.inspect
              all_stores << store
            end
          end
        end
      end
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
          s.phone = store[:phone]
          s.opening_hours = store[:hours]
        end
        puts "Promoqui_infos: " + s.inspect
        s.save
        all_stores << s.id
      rescue => e
        p "*"*100
        p store
        p e
      end
    end
    all_stores
  end


  def run
    PQSDK::Token.reset!
    PQSDK::Settings.host = 'api.promoqui.eu'
    PQSDK::Settings.app_secret = '9606d27c29347c1671fd7c000514ee24a4cd8f6fc9717f099320d57d86858455'
    stores = get_stores
    store_ids = update_store(stores)
    get_leaflet(store_ids.uniq)
  end
end

a = Superama.new
a.run
