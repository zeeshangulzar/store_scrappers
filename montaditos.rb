class Montaditos
  require 'net/http'
  require 'json'

  STORE_URL = 'https://italy.100montaditos.com/dove-siamo/'
  LEAFLET_URL = 'https://italy.100montaditos.com/promozioni/'

  def self.send_request(url)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.get(uri.request_uri)
  end

  def self.get_stores
    response = send_request(STORE_URL)
    stores_data = JSON.parse(response.body.scan(/locals_list = (.*);/).flatten.first)
    allStores = []
    stores_data.each do |store_data|
      store = {}
      store[:name] = store_data["title"]
      store[:address] = store_data["address"]
      store[:zipcode] = store_data["postal_code"]
      store[:phone_number] = store_data["phone_number"]
      store[:latitude] = store_data["latitude"]
      store[:longitude] = store_data["longitude"]
      store[:city] = store_data["city_tax"]
      allStores << store
    end
     allStores
  end

  def self.update_store(stores)
    store_ids = []
    stores.each do |store|
      s = PQSDK::Store.find(store[:address], store[:zipcode])
      if store.nil?
        s = PQSDK::Store.new
        s.name = store[:name]
        s.city = store[:city]
        s.address = store[:address]
        s.origin = STORE_URL
        s.latitude = store[:latitude]
        s.longitude = store[:longitude]
        s.zipcode = store[:zipcode]
        s.phone = store[:phone_number]
      end
      @report.info << "Store_infos: " + s.inspect
      s.save
      store_ids << s.id
    end
  end

  def self.get_leaflet_images
    response = send_request(LEAFLET_URL)
    images = response.body.scan(/\t<div class=\"bloque-imagen\">\n(.*)/).flatten
    images.collect(&:strip).collect {|str|str.scan(/<img src=\"(.*)\" alt=/)}.flatten
  end

  def self.get_leaflet(store_ids)
    leaflet_images = get_leaflet_images

    # puts "Download from --> #{pdf_url}"
    # leaflet = PQSDK::Leaflet.find LEAFLET_URL
    # if leaflet.nil?
    #   leaflet = PQSDK::Leaflet.new
    #   leaflet.name = "Leaflet"
    #   leaflet.start_date = leaflet.end_date = Time.now.to_s
    #   leaflet.url = LEAFLET_URL
    #   leaflet.store_ids = store_ids
    #   leaflet.save
    # end
  end

  def self.run
    stores = get_stores
    store_ids = update_store(stores)
    leaflet =  get_leaflet store_ids
    # p "========Stores====="
    # p stores
    # p "======Leaflet======="
    # p leaflet
  end
end

Montaditos.run

