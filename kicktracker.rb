#!/usr/bin/env ruby

require 'rubygems'
require 'mechanize'
require 'pp'

# URL to your Kickstarter project
url = "http://www.kickstarter.com/projects/571943958/tempt1-and-eyewriter-art-by-eyes"


filename = 'results.yml'
storage = ( File.exists?(filename) ? YAML.load(File.open(filename, 'r')) : [] )

agent = Mechanize.new
agent.user_agent = "Kicktracker <http://github.com/jamiew/kicktracker>"
page = agent.get(url)

money = (page/'#moneyraised')
counts = (money/'h5').map do |stat|
  stat.content.split("\n").select {|n| !n.nil? && !n.empty? }.compact
end

totals = {
  :time => DateTime.now.to_s,
  :backers => counts[0][0].to_i, 
  :raised => counts[1][0].gsub(',','').gsub('$','').to_i, 
  :goal => counts[1][1].match(/of (.*) goal/)[1].gsub('$','').gsub(',','').to_i,
  :days_left => counts[2][0].to_i
  }
pp totals
storage << totals

File.open(filename, 'w+') {|f| f.write(storage.to_yaml) }
exit 0

