# encoding: UTF-8
require 'yaml'
require 'open-uri'
require 'cgi'
require 'nokogiri'
require 'mail'

fetched = {}
first_run = true

def fix_string(string)
  string.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
end


loop do
  config = YAML.load_file('config.yaml')
  Mail.defaults do
    delivery_method :smtp, config[:smtp]
  end
  results = []

  config[:urls].each do |url|
    url += '&format=rss'
    # try fetching, if error, proceed to next URL
    begin
      doc = Nokogiri::XML(open(url))
    rescue => e
      puts "#{e} while fetching or parsing #{url}"
      next
    end

    doc.css('item').each do |item|
      link = fix_string(item.css('link').first.content)

      unless fetched.include?(link) || first_run
        results << {
          link: link,
          title: CGI.unescapeHTML(fix_string(item.css('title').first.content)),
          description: fix_string(item.css('description').first.content)
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
        reply_to config[:recipient]
        subject 'Craigsmail: ' + result[:title]
        body result[:link] + "\n\n" + result[:description]
      end
    end
  end

  first_run = false
  sleep config[:delay]
end
