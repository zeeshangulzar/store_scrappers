class Montaditos
  require 'net/http'
  require 'json'

  URL = "https://italy.100montaditos.com/dove-siamo/"

  def self.get_stores

    uri = URI.parse(URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.get(uri.request_uri)
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

  def self.run
    stores = get_stores
  end

end

Montaditos.run

