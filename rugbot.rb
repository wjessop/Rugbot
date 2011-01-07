require 'rubygems'
require 'isaac'
require 'twitter'
require 'curb'
require 'nokogiri'
require 'open-uri'
require 'cgi'
require 'json'

BOT_NAME = 'rugbot'

def ordinalize(number)
  if (11..13).include?(number.to_i % 100)
    "#{number}th"
  else
    case number.to_i % 10
      when 1; "#{number}st"
      when 2; "#{number}nd"
      when 3; "#{number}rd"
      else    "#{number}th"
    end
  end
end

configure do |c|
  c.nick    = BOT_NAME
  c.server  = "irc.freenode.net"
  c.port    = 6667
end

on :connect do
  join "#nwrug"
end

on :channel, /^(help|commands)$/ do
  msg channel, "roll, nextmeet, artme <string>"
end

on :channel, /^roll$/ do
  msg channel, "#{nick} rolls a six sided die and gets #{rand(6) +1}"
end

on :channel, /ACTION(.*)pokes #{Regexp.escape(BOT_NAME)}/ do
    action channel, "giggles at #{nick}"
end

# http://twitter.com/stealthygecko/status/20892091689
on :channel, /https?:\/\/twitter.com\/[\w-]+\/status\/(\d+)/ do |tweet_id|
  begin
    tweet = Twitter.status(tweet_id)
    user = tweet.user
  rescue Twitter::General => e
    puts "Caught #{e}"
  end
  msg channel, "#{tweet.text} - #{user.name} (#{user.screen_name})" if tweet
end

on :channel, /http:\/\/twitter\.com\/\#!\/(.*?)$/ do |user|
  begin
   u = Twitter.user(user)
   msg channel, "#{u.name} (#{u.screen_name}) - #{u.description} #{u.profile_image_url}"
   msg channel, "Last status: #{u.status.text}"
  rescue => e
   puts "Caught #{e}"
  end
end

on :channel, /(https?:\/\/\S+)/ do |url|
  begin
    title = Nokogiri::HTML(Curl::Easy.perform(url).body_str).css('title').first.content
    msg channel, "#{title}"
  rescue
  end
end

on :channel, /^nextmeet/ do
  beginning_of_month = Date.civil(Time.now.year, Time.now.month, 1)
  nwrug = beginning_of_month + (18 - beginning_of_month.wday)
  nwrug += 7 if beginning_of_month.wday > 4

  msg channel, nwrug.strftime("%A, #{ordinalize(nwrug.day)} %B")
end

on :channel, /^.* stabs/ do
  action channel, "stabs #{nick}"
end

on :channel, /^stab (.*?)$/ do |user|
  action channel, "stabs #{user}"
end

on :channel, /^artme (.*?)$/ do |art|
  begin
    if art == 'random'
      lns = File.readlines("/usr/share/dict/words")
      art = lns[rand(lns.size)].strip
    end
    doc = JSON.parse(open("http://ajax.googleapis.com/ajax/services/search/images?v=1.0&q="+CGI::escape(art)).read)
    msg channel, doc["responseData"]["results"][0]["url"]
  rescue
    msg channel, "No result"
  end
end
