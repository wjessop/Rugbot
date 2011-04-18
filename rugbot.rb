#encoding: utf-8
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
require 'meme'
require 'imgur'

require File.expand_path("rugbot_helper", File.dirname(__FILE__))

BOT_NAME = 'rugbot'
SEEN_LIST = {}
IMGUR_API_KEY = "4cdab1b0d1c8831232d477302a981363"

configure do |c|
  c.nick    = BOT_NAME
  c.server  = "irc.freenode.net"
  c.port    = 6667
end

on :connect do
  join "#nwrug"
end

on :channel, /^dance$/i do
  msg channel, "http://no.gd/caiusboogie.gif"
end

on :channel, /^meme ([A-Z_\-]+) (.+)$/i do |meme, words|
  log_user_seen(nick)
  begin
    meme = Meme.new(meme)
  
    imgur = Imgur::API.new(IMGUR_API_KEY)
    im = imgur.upload_from_url(meme.generate(words))
    msg channel, im['original_image']
  rescue Meme::Error
    meme = Meme.new('Y_U_NO')
    imgur = Imgur::API.new(IMGUR_API_KEY)
    im = imgur.upload_from_url(meme.generate("smart, #{nick}"))
    msg channel, im['original_image']
  end
end

on :channel, /^trollface$/i do
  log_user_seen(nick)
  msg channel, "http://images.whatport80.com/images/thumb/c/cf/Trollface.jpg/400px-Trollface.jpg"
end

on :channel, /^(help|commands)$/i do
  log_user_seen(nick)

  msg channel, "roll, nextmeet, artme <string>, stab <nick>, seen <nick>, ram, uptime, 37status, boobs, meme, trollface, dywj, dance"
end

on :channel, /dywj/ do
  log_user_seen(nick)

  msg channel, "DAMN YOU WILL JESSOP!!!"
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

  # Setup vars we need
  nwrug = nil
  details = nil

  begin
    # Grab ze string from ze website
    entry_title = Nokogiri::HTML(Curl::Easy.perform("http://nwrug.org/events/").body_str).css('.first_entry h3').first.content.gsub("\342\200\223", "-").strip
    # Figure out the details we want to return
    meeting_date, meeting_title = entry_title.split(" - ")

    if (d = Date.parse(meeting_date)) && d >= Date.today
      nwrug = d
      details = meeting_title
    end
  rescue
  end

  # In case we couldn't parse a current time from the website
  nwrug ||= nwrug_meet_for Time.now.year, Time.now.month

  date_string = case nwrug
  when Date.today
    "Today"
  when (Date.today + 1)
    "Tomorrow"
  else
    nwrug.strftime("%A, #{ordinalize(nwrug.day)} %B")
  end

  # compact makes sure we don't end up with "Today - ", but "Today" instead.
  msg channel, [date_string, details].compact.join(" - ")
end

on :channel, /^.* st[aа]bs/i do
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
    "#{nick}: I last saw #{user.inspect} speak at #{SEEN_LIST[user].strftime("%H:%M:%S on %d-%m-%y")}"
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
  rescue Twitter::Error => e
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
