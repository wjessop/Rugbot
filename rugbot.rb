require 'rubygems'
require "bundler/setup"

require 'isaac'
require 'twitter'
require 'curb'
require 'nokogiri'
require 'cgi'
require 'json'
require "time"

require File.expand_path("rugbot_helper", File.dirname(__FILE__))

BOT_NAME = 'rugbot'
SEEN_LIST = {}

configure do |c|
  c.nick    = BOT_NAME
  c.server  = "irc.freenode.net"
  c.port    = 6667
end

on :connect do
  join "#nwrug"
end

on :channel, /^(help|commands)$/ do
  log_user_seen(nick)

  msg channel, "roll, nextmeet, artme <string>, stab <nick>, seen <nick>, ram, uptime"
end

on :channel, /^roll$/ do
  log_user_seen(nick)

  msg channel, "#{nick} rolls a six sided die and gets #{rand(6) +1}"
end

on :channel, /ACTION(.*)pokes #{Regexp.escape(BOT_NAME)}/ do
  log_user_seen(nick)

    action channel, "giggles at #{nick}"
end

on :channel, /^nextmeet/ do
  log_user_seen(nick)

  beginning_of_month = Date.civil(Time.now.year, Time.now.month, 1)
  nwrug = beginning_of_month + (18 - beginning_of_month.wday)
  nwrug += 7 if beginning_of_month.wday > 4

  msg channel, nwrug.strftime("%A, #{ordinalize(nwrug.day)} %B")
end

on :channel, /^.* stabs/ do
  log_user_seen(nick)

  action channel, "stabs #{nick}"
end

on :channel, /^stab (.*?)$/ do |user|
  log_user_seen(nick)

  action channel, "stabs #{user}"
end

on :channel, /^artme (.*?)$/ do |art|
  log_user_seen(nick)

  begin
    if art == 'random'
      lns = File.readlines("/usr/share/dict/words")
      art = lns[rand(lns.size)].strip
    end
    url = "http://ajax.googleapis.com/ajax/services/search/images?v=1.0&q=#{CGI::escape(art)}"
    doc = JSON.parse(Curl::Easy.perform(url).body_str)
    msg channel, doc["responseData"]["results"][0]["url"]
  rescue
    msg channel, "No result"
  end
end

on :channel, /^seen (.*?)$/ do |user|
  log_user_seen(nick)

  user = user.downcase
  msg channel, if SEEN_LIST.has_key?(user)
    "#{nick}: I last saw #{user.inspect} speak at #{SEEN_LIST[user].strftime("%H:%M:%S on %y-%m-%d")}"
  else
    "#{nick}: not seen #{user.inspect} speak yet, sorry"
  end
end

# Replies with the current ram usage of this bot
on :channel, /^ram\s*$/ do
  log_user_seen(nick)

  usage = `ps -p #{Process.pid} -o rss=`.strip.chomp.to_i
  msg channel, ( "#{nick}: current usage is %.2f MB" % (usage/1024.0))
end

# Replies with the current uptime of this bot
on :channel, /^uptime\s*$/ do
  log_user_seen(nick)

  start_time = Time.parse(`ps -p #{Process.pid} -o lstart=`.strip.chomp)
  msg channel, "#{nick}: I've been running for #{(Time.now - start_time).to_time_length}"
end

# http://twitter.com/stealthygecko/status/20892091689
# http://twitter.com/#!/stealthygecko/status/20892091689
# And https | trailing /
on :channel, /https?:\/\/twitter.com(?:\/#!)?\/[\w-]+\/status\/(\d+)/ do |tweet_id|
  log_user_seen(nick)

  begin
    tweet = Twitter.status(tweet_id)
    user = tweet.user
  rescue Twitter::General => e
    puts "Caught #{e}"
  end
  msg channel, "#{tweet.text} - #{user.name} (#{user.screen_name})" if tweet
end

# http://twitter.com/stealthygecko
# http://twitter.com/#!/stealthygecko
# And https | trailing /
on :channel, /https?:\/\/twitter\.com(?:\/#!)?\/([^\/]+?)(?:$|\s)/ do |user|
  log_user_seen(nick)

  begin
   u = Twitter.user(user)
   msg channel, "#{u.name} (#{u.screen_name}) - #{u.description} #{u.profile_image_url}"
   msg channel, "Last status: #{u.status.text}"
  rescue => e
   puts "Caught #{e}"
  end
end

on :channel, /(https?:\/\/\S+)/ do |url|
  log_user_seen(nick)

  begin
    title = Nokogiri::HTML(Curl::Easy.perform(url).body_str).css('title').first.content
    msg channel, "#{title}"
  rescue
  end
end

# Catchall for seen
on :channel, /.*/ do
  log_user_seen(nick)
end

def log_user_seen nick
  SEEN_LIST[nick.downcase] = Time.now
end
