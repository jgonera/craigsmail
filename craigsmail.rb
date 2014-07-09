require 'yaml'
require 'open-uri'
require 'cgi'
require 'nokogiri'
require 'mail'

config = YAML.load_file('config.yaml')
fetched = {}
first_run = true

Mail.defaults do
  delivery_method :smtp, config[:smtp]
end


loop do
  results = []

  config[:urls].each do |url|
    url += '&format=rss'
    doc = Nokogiri::XML(open(url))

    doc.css('item').each do |item|
      link = item.css('link').first.content

      unless fetched.include?(link) || first_run
        results << {
          link: link,
          title: CGI.unescapeHTML(item.css('title').first.content),
          description: item.css('description').first.content
        }
      end

      fetched[link] = true
    end
  end

  unless results.empty?
    puts Time.new
    puts YAML.dump(results)

    results.each do |result|
      Mail.deliver do
        from 'craigsmail@dummy.com'
        to config[:recipient]
        subject 'Craigsmail: ' + result[:title].encode!('UTF-8', 'UTF-8', invalid: :replace)
        body result[:link] + "\n\n" + result[:description].encode!('UTF-8', 'UTF-8', invalid: :replace)
      end
    end
  end

  first_run = false
  sleep config[:delay]
end
