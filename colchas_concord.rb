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

class ColchasConcord

  STORE_URL = 'https://www.colchasconcord.com.mx/sucursales'
  LEAFLET_URL = 'http://tienda.colchasconcord.com.mx/qr/catalogodigital'

  def get_leaflet(store_ids)
    doc = Nokogiri::HTML(open(LEAFLET_URL))
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

  def get_stores
    all_stores = []
    doc = Nokogiri::HTML(open(STORE_URL))
    page_count = doc.css('.pages-items .item .last span').last.text.to_i
    (1..page_count).each do |page_number|
      page_url = STORE_URL + "?p=#{page_number}"
      doc = Nokogiri::HTML(open(page_url))
      markers = doc.css('script').map {|s| s.content.scan(/var markers = (.*);/m)}.flatten.first.split("],\n")[0..-2]
      markers.each do |store_data|
        begin
          store = {}
          store[:name] = store_data.scan(/<h3>(.*)<\/h3>/).flatten.first
          store[:latitude] = store_data.split(",")[-2]
          store[:longitude] = store_data.split(",")[-1]
          location = Geocoder.search([store[:latitude], store[:longitude]]).first
          store[:city] =  location.try(:city)
          zipcode = store_data.split(" MX</p>").first.split(' ').last
          store[:address] = store_data.scan(/<\/h3><p>(.*)#{zipcode}/).flatten.first.strip
          if !zipcode.nil? && zipcode.length < 5
            zipcode = "0"* (5 - zipcode.length) + zipcode
          end
          store[:zipcode] = zipcode
          store[:phone] = store_data.split("</a>")[0].split("\">").last.gsub(' ','' )
          all_stores << store
          puts "Store_infos: " + store.inspect
        rescue => e
          p "*"*100
          p store
        end
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
        end
        puts "Promoqui_infos: " + s.inspect
        s.save
        store_ids << s.id
      rescue => e
        p "-"*100
        p s
      end
    end
    store_ids
  end


  def run
    PQSDK::Token.reset!
    PQSDK::Settings.host = 'api.promoqui.eu'
    PQSDK::Settings.app_secret = 'cf70fa6e7fc9abccb35f570c0853a90e193993ee3c549cfc4aa5ec42a6135a52'
    stores = get_stores
    store_ids = update_store(stores)
    get_leaflet(store_ids.uniq)
  end
end

a = ColchasConcord.new
a.run
