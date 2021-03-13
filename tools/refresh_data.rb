#!/usr/bin/env ruby
require 'json'
require 'open-uri'
require 'fileutils'

# github_api_token = ENV.fetch('GITHUB_API_TOKEN')
wowrepio_api_token = ENV.fetch('WOWREPIO_API_TOKEN')

data = JSON.parse(URI.open('https://wowrep.io/api/scores?token=' + wowrepio_api_token).read)
lua_template_line = 'ns.DATABASE["%KEY%"] = { average = %AVERAGE%, factors = { skill = %SKILL%, teamplay = %TEAMPLAY%, communication = %COM% } }'
to_be_lua_lines = {}
lua_lines = []

data.select do |record|
  record.values[0]['average'] != nil
end.each do |record|
  to_be_lua_lines[record.keys[0]] = record.values[0]
end

to_be_lua_lines.each do |k,v|
  lua_lines << lua_template_line.gsub('%KEY%', k).gsub('%AVERAGE%', '%.2f' % v['average']).gsub('%SKILL%', '%.2f' % v['skill']).gsub('%TEAMPLAY%', '%.2f' % v['teamplay']).gsub('%COM%', '%.2f' % v['communication'])
end

FileUtils.cp("./db/_db_template.lua", "./db/db.lua")
open('./db/db.lua', 'a') { |f|
  lua_lines.each{ |line| f.puts "\n" + line }
}

`git add .`
`git commit -m'Update db.lua'`
`git push origin master`
`git tag #{Time.now.to_s.gsub(' ','').gsub('-', '').gsub(':', '')}`
`git push origin master`
`git push --tags`

puts "Done!"