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

class Sorinana

  STORE_URL = 'http://www.sorianadomicilio.com/site/default.aspx?p=10129&pcdt=Q'
  ROOT_URL = 'http://www.sorianadomicilio.com/site/default.aspx'
  LEAFLET_URL = 'http://www.sorianadomicilio.com/site/default.aspx?p=12116'
  ISSU_URL = 'https://e.issuu.com/config/'
  LEAFLET_IMAGE_URL = 'https://reader3.isu.pub'

  def get_leaflet store_ids
    leaflet_images = []
    page = Nokogiri::HTML(open(LEAFLET_URL))
    page_id = page.css('iframe').last.attr('src').split('#').last.split('/').last
    issu_url = [ISSU_URL, page_id, '.json'].join
    issu_page = Nokogiri::HTML(open(issu_url))
    issu_data = JSON.parse(issu_page)
    leaflet_images_url = [LEAFLET_IMAGE_URL, issu_data["ownerUsername"], issu_data["documentURI"], 'reader3_4.json'].join('/')
    doc = Nokogiri::HTML(open(leaflet_images_url))
    leaflet_images = JSON.parse(doc.css('body').text)["document"]["pages"].map {|a| a["imageUri"]}
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
    stores_data = doc.css('.txt_g_12pxubica a')
    stores_data.each do |store_data|
      store = {}
      store[:city] = store_data.text
      store_url = ROOT_URL + store_data.attr('href')
      store_entry = doc = Nokogiri::HTML(open(store_url))
      enteries = store_entry.css('.tabla_selectsuc1 .txt_selectsuc')
      byebug
      store[:name] = enteries[0].text
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
    # PQSDK::Token.reset!
    # PQSDK::Settings.host = 'api.promoqui.eu'
    # PQSDK::Settings.app_secret = '47588bffd1291f79476b376f805df479ea489e68f622db994c6b0e5631d22726'
    stores = get_stores
    store_ids = update_store(stores)
    get_leaflet(store_ids)
  end
end

a = Sorinana.new
a.run
