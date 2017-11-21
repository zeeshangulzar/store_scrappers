require 'pqsdk'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'byebug'

class ProfumeriaPinalli

  STORE_URL = 'https://www.pinalli.it/punti-vendita/'

  def get_stores
    store_array = []
    doc = Nokogiri::HTML(open(STORE_URL))
    stores = doc.css('script').map {|s| s.content.scan(/var companies = (.*)infos =/m)}.flatten.first
    byebug
    stores_data = parse_store_data(stores)
    byebug

  end

 def parse_store_data(stores)
  stores = stores.gsub(/<\/?[^>]*>/, " ").gsub("\r\n", "")
  stores.split("],").map { |s| s.gsub("[", "").gsub("'", '') }
 end

  def run
    # PQSDK::Token.reset!
    # PQSDK::Settings.host = 'api.promoqui.eu'
    # PQSDK::Settings.app_secret = '1904fbed9987ee6cd5653d558f8ad9e8ce281f94bc01a44b50adc64fbc95d612'
    stores = get_stores
  end
end

a = ProfumeriaPinalli.new
a.run
