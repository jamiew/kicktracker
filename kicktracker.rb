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

html_filename = dirname+'/output.html'
results_filename = dirname+'/results.yml'
results = ( File.exists?(results_filename) ? YAML.load(File.open(results_filename, 'r')) : [] )

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
results << totals



# Regenerate output.html
raised_by_hour = results.group_by{|x| date = DateTime.parse(x[:time]); date.strftime('%m/%y %H') }.map{|k,v| [k, v[-1][:raised]] }.sort_by{|a| a[0] }

total = results[0][:goal]
html = ''

html += <<-HEREDOC
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta http-equiv="content-type" content="text/html; charset=utf-8"/>
    <title>
      Google Visualization API Sample
    </title>
    <script type="text/javascript" src="http://www.google.com/jsapi"></script>
    <script type="text/javascript">
      google.load('visualization', '1', {packages: ['corechart']});
    </script>
    <script type="text/javascript">
      function drawVisualization() {
        var data = new google.visualization.DataTable();
        data.addColumn('string', 'Date');
        data.addColumn('number', 'Raised');
        data.addColumn('number', 'Target');
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
  html += "data.addRow(['#{label}', #{a[1]}, #{total}]);"
  html += "\n"
end

html += <<-HEREDOC
        new google.visualization.LineChart(document.getElementById('visualization')).
            draw(data, {curveType: "function", width: 500, height: 400, vAxis: {maxValue: 10}});
      }
      google.setOnLoadCallback(drawVisualization);
    </script>
  </head>
  <body style="font-family: Arial;border: 0 none;">
    <div id="visualization" style="width: 500px; height: 400px;"></div>
  </body>
</html>
HEREDOC

File.open(html_filename, 'w+') {|f| f.write(results.to_yaml) }
# puts html


# Write to results.yml & print
File.open(results_filename, 'w+') {|f| f.write(results.to_yaml) }
pp results
