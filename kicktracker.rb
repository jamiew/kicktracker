##
#!/usr/bin/env ruby

require 'rubygems'
require 'mechanize'
require 'pp'

# URL to your Kickstarter project
dirname = File.expand_path(File.dirname(__FILE__))
config = YAML.load(File.open(dirname+'/config.yml').read)
raise "You must specify a Kickstarter project url in config.yml" if config.nil? || config['url'].empty?
url = config['url']

# Graph options
html_filename = dirname+'/output.html'
width = config['width'] && config['width'] || 600
height = config['height'] && config['height'] || 500

# Results
results_filename = dirname+'/results.yml'
results = ( File.exists?(results_filename) ? YAML.load(File.open(results_filename, 'r')) : [] )

agent = Mechanize.new
agent.user_agent = "Kicktracker <http://github.com/jamiew/kicktracker>"
page = agent.get(url)

money = (page/'#moneyraised')
counts = (money/'h5').map do |stat|
  stat.content.split("\n").select {|n| !n.nil? && !n.empty? }.compact
end

title = (page/'#name')[0].content
byline = (page/'#headrow p')[0].content.split('•')[0]

totals = {
  :time => DateTime.now.to_s,
  :backers => counts[0][0].to_i,
  :raised => counts[1][0].gsub(',','').gsub('$','').to_i,
  :goal => counts[1][1].match(/of (.*) goal/)[1].gsub('$','').gsub(',','').to_i,
  :days_left => counts[2][0].to_i
}
results << totals



# Regenerate output.html
raised_by_hour = results.group_by{|x| date = DateTime.parse(x[:time]); date.strftime('%m/%y %H') }.map{|k,v| [k, v[-1][:raised]] }.sort_by{|a| a[0] }

total = results[-1][:goal]
raised = results[-1][:raised]
remaining = total - raised
backers = results[-1][:backers]
days_left = results[-1][:days_left]
updated_at = DateTime.parse(results[-1][:time])

html = <<-HEREDOC
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta http-equiv="content-type" content="text/html; charset=utf-8"/>
    <title>
      Kicktracker - #{title}
    </title>
    <script type="text/javascript" src="http://www.google.com/jsapi"></script>
    <script type="text/javascript">
      google.load('visualization', '1', {packages: ['corechart']});
    </script>
    <script type="text/javascript">
      function drawVisualization() {
        var data = new google.visualization.DataTable();
        data.addColumn('string', 'Date');
        data.addColumn('number', 'Target');
        data.addColumn('number', 'Raised');
HEREDOC

last_date = ''
raised_by_hour.each do |a|
  arg = a[0].split(' ')[0].gsub(/^0/,'')
  if last_date == arg
    label = ''
  else
    label = last_date = arg
  end

  html += "\t\t"
  html += "data.addRow(['#{label}', #{total}, #{a[1]}]);"
  html += "\n"
end

html += <<-HEREDOC
        new google.visualization.LineChart(document.getElementById('visualization')).
            draw(data, {
                curveType: "function",
                width: #{width}, height: #{height},
                vAxis: {maxValue: 10, format: '$#,###'}
            });
      }
      google.setOnLoadCallback(drawVisualization);
    </script>
    <style type="text/css">
      #wrapper { margin: 0 auto; width: #{width}px; }
      #info { margin-left: 70px; }
      a { color: #000; }
      h1#title { font-size: 15pt; margin-bottom: 5px; }
      h2#byline { font-size: 13pt; font-weight: normal; font-style: italic; margin-top: 0; margin-bottom: 20px; }
      ul.stats { padding-left: 16px; font-size: 11pt; }
      #updated_at { margin-top: 30px; font-size: 10pt; color: #888; }
    </style>
  </head>
  <body style="font-family: Arial;border: 0 none;">
    <div id="wrapper">
      <div id="visualization" style="width: #{width}px; height: #{height}px;"></div>

      <div id="info">
        <h1 id="title"><a href="#{url}">#{title}</a></h1>
        <h2 id="byline">#{byline}</h2>

        <ul class="stats">
          <li>$#{raised} raised</li>
          <li>#{(raised.to_f/total.to_f*100.0).round}% complete</li>
        </ul>

        <ul class="stats">
          <li>#{backers} backers</li>
          <li>Avg $#{(raised.to_f/backers.to_f).round}/backer</li>
        </ul>

        <ul class="stats">
          <li>#{days_left} days left</li>
          <li>Goal: $#{(remaining.to_f/days_left.to_f).round} per day</li>
        </ul>

        <div id="updated_at">
          Last updated #{updated_at.strftime('%D %T')}
        </div>

      </div>
    </div>
  </body>
</html>
HEREDOC

File.open(html_filename, 'w+') {|f| f.write(html) }
# puts html


# Write to results.yml & print
File.open(results_filename, 'w+') {|f| f.write(results.to_yaml) }
puts url
pp totals
