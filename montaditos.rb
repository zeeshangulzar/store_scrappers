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
      store[:postal_code] = store_data["postal_code"]
      store[:phone_number] = store_data["phone_number"]
      store[:latitude] = store_data["latitude"]
      store[:longitude] = store_data["longitude"]
      store[:city] = store_data["city_tax"]
      allStores << store
    end
     allStores
  end

  def self.get_leaflet
    response = send_request(LEAFLET_URL)
    leaflet_images = response.body.scan(/\t<div class=\"bloque-imagen\">\n(.*)/).flatten
    leaflet_images = leaflet_images.collect(&:strip).collect {|str|str.scan(/<img src=\"(.*)\" alt=/)}.flatten
  end

  def self.run
    stores = get_stores
    leaflet =  get_leaflet
  end
end

Montaditos.run

