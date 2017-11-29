require 'pqsdk'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'byebug'

class Lacomer

  STORE_URL = 'https://vasalsuperoalacomer.com/comer/sucursales'
  STATE_URL = 'https://vasalsuperoalacomer.com/comer/scripts/estados.php'
  BRANCH_URL = 'https://vasalsuperoalacomer.com/comer/scripts/sucursales.php?id='
  ENITITY_URL = 'https://vasalsuperoalacomer.com/comer/scripts/sucursal.php?id='

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
        store[:city] = map_values[1].split(",").last.strip
        coords = map_values[2]
        store[:latitude] = coords.first
        store[:longitude] =  coords.last
        store[:zipcode] = map_values[1].split(",")[-3].gsub(/[^\d]/, '')
        store[:address] = map_values[1].split(store[:zipcode]).first.strip[0..-2]
        puts "Store_infos: " + store.inspect
        all_stores << store
      end
    end
    all_stores
  end

  def update_store(stores)
    stores.each do |store|
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
    end
  end


  def run
    PQSDK::Token.reset!
    PQSDK::Settings.host = 'api.promoqui.eu'
    PQSDK::Settings.app_secret = 'c055acc7635b13f68782141db920a996ecac3e78ef4545df60b2ed5febf6a2d7'
    stores = get_stores
    update_store(stores)
  end
end

a = Lacomer.new
a.run
