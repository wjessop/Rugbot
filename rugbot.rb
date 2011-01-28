require 'rubygems'
require "bundler/setup"

require 'isaac'
require 'twitter'
require 'curb'
require 'nokogiri'
require 'cgi'
require 'json'
require "time"
require "uri"

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

on :channel, /^(help|commands)$/i do
  log_user_seen(nick)

  msg channel, "roll, nextmeet, artme <string>, stab <nick>, seen <nick>, ram, uptime, 37status, boobs"
end

on :channel, /^roll$/i do
  log_user_seen(nick)

  msg channel, "#{nick} rolls a six sided die and gets #{rand(6) +1}"
end

on :channel, /ACTION(.*)pokes #{Regexp.escape(BOT_NAME)}/i do
  log_user_seen(nick)

    action channel, "giggles at #{nick}"
end

on :channel, /^37status$/i do
  log_user_seen(nick)

   doc = JSON.parse(Curl::Easy.perform('http://status.37signals.com/status.json').body_str)
   msg channel, "#{doc['status']['mood']}: #{doc['status']['description']}"
end

on :channel, /^nextmeet/i do
  log_user_seen(nick)

  beginning_of_month = Date.civil(Time.now.year, Time.now.month, 1)
  nwrug = beginning_of_month + (18 - beginning_of_month.wday)
  nwrug += 7 if beginning_of_month.wday > 4
  
  begin
    # Grab ze string from ze website
    entry_title = Nokogiri::HTML(Curl::Easy.perform("http://nwrug.org/events/").body_str).css('.first_entry h3').first.content.gsub("\342\200\223", "-").strip
    # Figure out the details we want to return
    meeting_date, meeting_title = entry_title.split(" - ")
    details = case Date.parse(meeting_date  )
    when Date.today
      "TODAY - #{meeting_title}"
    when (Date.today + 1)
      "It's tomorrow - #{meeting_title}"
    else
      meeting_date <= Date.today ? nil : entry_title
    end
  rescue
  end

  details ||= ["dunno, pester wlll about it", "no freaking idea, prod wlll for details", "oi wlll, got some nutter here actually wanting to attend. Deal wiv 'im.", "E_NO_DATE, 'wlll is at fault'", "I'm sorry, wlll hasn't entrusted me with that information", "Talk to wlll...", "Ask wlll, he's the brain behind these operations", "I'm just a simple bot, my master wlll has that information"].shuffle.first

  msg channel, details
end

on :channel, /^.* stabs/i do
  log_user_seen(nick)

  action channel, "stabs #{nick}" unless nick == "rugbot"
end

on :channel, /^stab (.*?)$/i do |user|
  log_user_seen(nick)
  user = nick if user == "rugbot"

  action channel, "stabs #{user}"
end

on :channel, /^b(oo|ew)bs$/ do |user|
  log_user_seen(nick)

  msg channel, "(.)(.)"
end

on :channel, /^artme (.*?)$/i do |art|
  log_user_seen(nick)

  begin
    if art == 'random'
      lns = File.readlines("/usr/share/dict/words")
      art = lns[rand(lns.size)].strip
    end
    url = "http://ajax.googleapis.com/ajax/services/search/images?v=1.0&q=#{CGI::escape(art)}"
    doc = JSON.parse(Curl::Easy.perform(url).body_str)
    msg channel, URI::unescape(doc["responseData"]["results"][0]["url"])
  rescue
    msg channel, "No result"
  end
end

on :channel, /^seen (.*?)$/i do |user|
  log_user_seen(nick)

  user = user.downcase
  msg channel, if SEEN_LIST.has_key?(user)
    "#{nick}: I last saw #{user.inspect} speak at #{SEEN_LIST[user].strftime("%H:%M:%S on %y-%m-%d")}"
  else
    "#{nick}: not seen #{user.inspect} yet, sorry"
  end
end

# Replies with the current ram usage of this bot
on :channel, /^ram\s*$/i do
  log_user_seen(nick)

  usage = `ps -p #{Process.pid} -o rss=`.strip.chomp.to_i
  msg channel, ( "#{nick}: current usage is %.2f MB" % (usage/1024.0))
end

# Replies with the current uptime of this bot
on :channel, /^uptime\s*$/i do
  log_user_seen(nick)

  start_time = Time.parse(`ps -p #{Process.pid} -o lstart=`.strip.chomp)
  msg channel, "#{nick}: I've been running for #{(Time.now - start_time).to_time_length}"
end

# http://twitter.com/stealthygecko/status/20892091689
# http://twitter.com/#!/stealthygecko/status/20892091689
# And https | trailing /
on :channel, /https?:\/\/twitter.com(?:\/#!)?\/[\w-]+\/status\/(\d+)/i do |tweet_id|
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
on :channel, /https?:\/\/twitter\.com(?:\/#!)?\/([^\/]+?)(?:$|\s)/i do |user|
  log_user_seen(nick)

  begin
   u = Twitter.user(user)
   msg channel, "#{u.name} (#{u.screen_name}) - #{u.description} #{u.profile_image_url}"
   msg channel, "Last status: #{u.status.text}"
  rescue => e
   puts "Caught #{e}"
  end
end

on :channel, /(https?:\/\/\S+)/i do |url|
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
