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

class Lacomer

  STORE_URL = 'https://vasalsuperoalacomer.com/comer/sucursales'
  STATE_URL = 'https://vasalsuperoalacomer.com/comer/scripts/estados.php'
  BRANCH_URL = 'https://vasalsuperoalacomer.com/comer/scripts/sucursales.php?id='
  ENITITY_URL = 'https://vasalsuperoalacomer.com/comer/scripts/sucursal.php?id='
  LEAFLET_URL = 'https://vasalsuperoalacomer.com/comer/folleto'
  ROOT_URL = 'https://vasalsuperoalacomer.com/comer/'
  LEAFLET_INDEX = 'https://www.lacomer.com.mx/lacomer/doHome.action?key=Lomas-Anahuac&succId=14&succFmt=100&pago=false'
  LEAFLET_MENU_URL = 'https://www.lacomer.com.mx/lacomer/doHeaderLoad.action'

  def get_leaflet(store_ids)
    page = open(LEAFLET_INDEX)
    cookie = page.meta["set-cookie"]
    doc = open(LEAFLET_MENU_URL, "Cookie" => cookie).read
    urls = JSON.parse(doc)["folletos"].map {|a| a["url"].strip }

    urls.each do |url|
      leaflet_page = Nokogiri::HTML(open(url))
      leaflet_images =  leaflet_page.css('.bb-item img').map {|image| [ROOT_URL, image.attr('src')].join }
      leaflet = PQSDK::Leaflet.find url
      if leaflet.nil?
        leaflet = PQSDK::Leaflet.new
        leaflet.name = "Leaflet"
        leaflet.start_date = leaflet.end_date = Time.now.to_s
        leaflet.image_urls = leaflet_images
        leaflet.url = url
        leaflet.store_ids = store_ids
        leaflet.save
      end
    end
  end

  def format_address(address)
    address = address.gsub("La Comer, ",  '').gsub("Ã", '').gsub("©", '')
    address.gsub("\u0081", '').gsub('La Comer', '').gsub("º", '').strip
  end

  def get_city(store)
    location = Geocoder.search([store[:latitude], store[:longitude]]).first
    location.try(:city)
  end

  def get_stores
    all_stores = []
    doc = Nokogiri::HTML(open(STATE_URL))
    states = doc.css('body option').map { |state| state.attr('value') }
    states.shift
    states.each do |state_id|
      branch_url = BRANCH_URL + state_id
      branches = Nokogiri::HTML(open(branch_url)).css('body option').map {|branch| branch.attr('value')}
      branches.shift
      branches.each do |branch_id|
        entity_url = ENITITY_URL + branch_id
        page = Nokogiri::HTML(open(entity_url)).css('body').text
        page_data = JSON.parse(page)
        store = {}
        store[:name] = page_data["nombre"].strip
        phone = page_data["telefono"].split('|')
        phone1 = phone.first
        unless phone1.nil?
          ph_number = phone1.gsub(/[^\d]/, '')
          if ph_number.length < 4
            ph_number = phone[1]
          end
         store[:phone] = ph_number.gsub(/[^\d]/, '')
        end
        map = Nokogiri::HTML(open(page_data["url"]))
        map_data = map.css('script').map {|s| s.content.scan(/initEmbed(.*)\)/)}.flatten.first
        map_values = JSON.parse(map_data[1..-1]).compact[4][3][0]
        coords = map_values[2]
        store[:latitude] = coords.first
        store[:longitude] =  coords.last
        store[:zipcode] = map_values[1].split(",")[-3].gsub(/[^\d]/, '')
        address = map_values[1].split(store[:zipcode]).first.strip[0..-2]
        store[:address] = format_address(address)
        puts "Store_infos: " + store.inspect
        all_stores << store
      end
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
        s.city =  get_city(store)
        s.address = store[:address]
        s.origin = STORE_URL
        s.latitude = store[:latitude]
        s.longitude = store[:longitude]
        s.zipcode = store[:zipcode]
        s.phone = store[:phone]
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
    PQSDK::Settings.app_secret = 'c055acc7635b13f68782141db920a996ecac3e78ef4545df60b2ed5febf6a2d7'
    stores = get_stores
    store_ids = update_store(stores)
    # store_ids = [81239, 81240, 81241, 81242, 81243, 81244, 81245, 81246, 81247, 81248, 81249, 81250, 81251, 81252, 81253, 81254, 81255, 81256, 81257, 81258, 81259, 81260, 81261, 81262, 81263, 81264, 81265, 81266, 81267]
    get_leaflet(store_ids)
  end
end

a = Lacomer.new
a.run
