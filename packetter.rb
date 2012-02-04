#!/usr/local/bin/ruby -Ku

require 'rubygems'
require 'mechanize'
require 'nkf'
require 'open-uri'
require 'net/https'
require 'erb'

load File.join(File.dirname(__FILE__), 'config.rb')

# logger
#require 'logger'
#Mechanize.log = Logger.new('packetter.txt')
#Mechanize.log.level = Logger::DEBUG

# setup
puts 'setup...'
agent = Mechanize.new
agent.follow_meta_refresh = true
agent.user_agent = 'Mozilla/5.0 (iPhone; U; CPU iPhone OS 2_0 like Mac OS X; ja-jp) AppleWebKit/525.18.1 (KHTML, like Gecko) Version/3.1.1 Mobile/5A345 Safari/525.20'

# login
puts 'login...'
agent.get('https://my.softbank.jp/msb/d/top')
agent.page.forms.first.field_with(:name => 'msn').value = $my_softbank[:user_id]
agent.page.forms.first.field_with(:name => 'password').value = $my_softbank[:password]
agent.page.forms.first.click_button

# jump to mainmenu
puts 'jump to mainmenu...'
agent.get('https://my.softbank.jp/msb/d/webLink/doSend/WCO010000')

# jump to mainmenu
puts 'redirect to mainmenu...'
agent.page.forms.first.submit

# jump to bill_before_fixed
puts 'jump to bill_before_fixed...'
agent.get('https://bl11.my.softbank.jp/wco/billBeforeFixed/WCO020')

# get contents
td = agent.page.search('form[@name="billBeforeFixedActionForm"]').inner_text.gsub(/[\r\n]/, '')

# date
td =~ /年([0-9]+月[0-9]+日)）/
date = $1
puts "date : #{date}"

# packet fee
list = td.scan(/通信料.+?([0-9,]+)円/)
fee = 0
list.each do |item|
  fee += item[0].gsub(/,/, '').to_i
end
fee = "#{fee.to_s.gsub(/(.*\d)(\d\d\d)/, '\1,\2')}円"
puts "packet fee : #{fee}"

# latest file
latest_file = File.join(File.dirname(__FILE__), 'latest')

# load latest and compare
if File.exist?(latest_file)
  puts 'load latest...'
  f = open(latest_file)
  latest = f.read.chomp
  f.close

  # compare
  fee_new = fee.delete(',').to_i
  fee_old = latest.delete(',').to_i
  fee_diff = fee_new - fee_old
  if fee_diff < 0
    diff = ''
  else
    diff = " (+#{fee_diff.to_s.gsub(/(.*\d)(\d\d\d)/, '\1,\2')}円)"
  end
  puts "diff : #{diff}"
end

# save latest
f = File.open(latest_file, 'w')
f.puts fee
f.close

# post
puts 'post...'
https = Net::HTTP.new('boxcar.io', 443)
https.use_ssl = true
https.start() do |http|
  req = Net::HTTP::Post.new('/notifications')
  req.basic_auth $boxcar[:user_id], $boxcar[:password]
  req.body = 'notification[from_screen_name]=packetter&notification[message]=' + ERB::Util.u("#{date}までのSoftBankパケット通信料 : #{fee}#{diff} http://tinyurl.com/packetter")
  res = http.request(req)
end

puts 'finished.'
