require 'rubygems'
require 'isaac'
require 'twitter'
require 'curb'
require 'nokogiri'
require 'open-uri'
require 'cgi'
require 'json'

configure do |c|
  c.nick    = "rugbot"
  c.server  = "irc.freenode.net"
  c.port    = 6667
end

on :connect do
  join "#nwrug"
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
  msg channel, "Third Thursday"
end

on :channel, /^artme (.*?)$/ do |art|
  begin
    doc = JSON.parse(open("http://ajax.googleapis.com/ajax/services/search/images?v=1.0&q="+CGI::escape(art)).read)
    msg channel, doc["responseData"]["results"][0]["url"]
  rescue
    msg channel, "No result"
  end
end
