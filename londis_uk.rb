require 'pqsdk'

class Crawler::Uk::LondisUk < Crawler::Base

  RETAILER_NAME = 'Londis'

  def get_hours doc
    hours = doc.xpath("//ul[@class='lf_days']/li")
    ret = []
    return ret if hours.empty?

    [0,1,2,3,4,5,6].each do |n|
      begin
        oh = {}
        oh[:weekday] = n
        oh[:open_am] = hours[n].text.strip.match(/([0-9]{2}:[0-9]{2}) - ([0-9]{2}:[0-9]{2})/)[1]
        oh[:close_pm] = hours[n].text.match(/([0-9]{2}:[0-9]{2}) - ([0-9]{2}:[0-9]{2})/)[2]
        ret << oh
      rescue
        p 'orario non aggiunto -->' + hours[n].text.strip.inspect
      end
    end

    ret
  end

  def get_leaflet url, storeIds
    doc = Nokogiri::HTML(open(url))
    l_url = "http://www.londis.co.uk/latest-offers/#{doc.xpath("//a[@id='view-more-offers']").attribute('href').value}"
    begin
      doc = Nokogiri::HTML(open("#{l_url}/js/bookSettings.js")).text
    rescue Exception => e
      @report.info << e.message
      return nil
    end

    pdf_location = doc.match(/"([a-zA-Z0-9]+.pdf)/)[1]
    pdf_url = "#{l_url}/#{pdf_location}" #URL FINALE
    images = []

    begin
      open(pdf_url)
    rescue OpenURI::HTTPError => err
      #@report.info << "PDF Url not valid: #{err}"
      p "PDF Url not valid: #{err}"
      doc = open(l_url+'/js/bookSettings.js').read
      doc = doc.gsub("\n\t",'')
      pages = doc.scan(/(pages\/[a-zA-Z0-9\-\.\/\_]+)/).flatten
      pages.each do |page|
        images << l_url + '/' + page.gsub('pages','pages/large')
      end
    end

    file_name = 'Leaflet'
    file_start = Time.now.to_s
    file_end = Time.now.to_s

    p "Leaflet url --> #{pdf_url}"
    if images.blank?
      leaflet = PQSDK::Leaflet.find pdf_url
      if leaflet.nil?
        leaflet = PQSDK::Leaflet.new
        leaflet.name = file_name
        leaflet.start_date = file_start
        leaflet.end_date = file_end
        leaflet.url = pdf_url
        leaflet.store_ids = storeIds
        leaflet.save
      end
    else
      leaflet = PQSDK::Leaflet.find l_url
      if leaflet.nil?
        leaflet = PQSDK::Leaflet.new
        leaflet.name = file_name
        leaflet.start_date = file_start
        leaflet.end_date = file_end
        leaflet.image_urls = images
        leaflet.url = l_url
        leaflet.store_ids = storeIds
        leaflet.save
      end
    end
  end

  def update_store store_data
    store_url = "http://supermarket.londis.co.uk/#{store_data['url']}"
    doc = Nokogiri::HTML(open(store_url))

    store_name = "#{RETAILER_NAME} #{store_data['name'].gsub('Londis,', '').gsub('Londis', '').gsub(',', '').strip}"
    store_zip = store_data['postal_code'].empty? ? 0 : store_data['postal_code'].strip

    if doc.xpath('//address')[0].to_s.split('<br>').count == 1
      store_address = doc.xpath('//address/div[@itemprop="streetAddress"]').text.strip
    elsif doc.xpath('//address')[0].to_s.split('<br>').count == 2
      store_address = doc.xpath('//address/div[@itemprop="streetAddress"]').to_s.split('<br>')[0].split('>')[1].strip
    elsif doc.xpath('//address')[0].to_s.split('<br>').count == 3
      store_address = doc.xpath('//address/div[@itemprop="streetAddress"]')[0].to_s.split('<br>')[0].gsub('<address>', '').strip
    end
    store_lat = store_data['lat']
    store_lng = store_data['lng']

    hours = get_hours doc

    store = PQSDK::Store.find(store_address, store_zip)
    if store.nil?
      store_city = Geocoder.search("[#{store_lat},#{store_lng}]").first.city
      store = PQSDK::Store.new
      store.name = store_name.strip
      store.city = store_city
      store.address = store_address
      store.origin = store_url
      store.zipcode = store_zip
    end
    store.opening_hours = hours unless hours.blank?
    store.save
    store.id
  end

  def run

    PQSDK::Token.reset!

    #Debug
    #PQSDK::Settings.host = 'c-api.promoqui.dev:3001'
    #PQSDK::Settings.app_secret = 'dfd97beac33fd8c1c9e24f8f738e796b28e1aa5c07a5eb15f0a8e8c7dee3e366'

    url = 'http://supermarket.londis.co.uk/points_of_sale.json'
    stores = JSON.parse(open(url).read)['points_of_sale']['United Kingdom'].map{|x,y| y}

    store_ids = []
    stores.each do |store|
      begin
        store_ids << update_store(store)
      rescue Exception => e
        @report.info << 'Skipping ' + e.to_s
      end
    end

    get_leaflet 'http://www.londis.co.uk/latest-offers/', store_ids.uniq

  end

end
