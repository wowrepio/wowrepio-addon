#!/usr/bin/env ruby
require 'json'
require 'open-uri'
require 'fileutils'

P = 0x1F
M = 0x3B9ACA09

def wowrepioHash(str = '')
  v = 0
  pp = 1

  str.each_char do |c|
    v = (v + (c.ord - 'a'.ord + 1) * pp) % M
    pp = (pp * P) % M
  end

  return v
end

# github_api_token = ENV.fetch('GITHUB_API_TOKEN')
wowrepio_api_token = ENV.fetch('WOWREPIO_API_TOKEN')

data = JSON.parse(URI.open('https://wowrep.io/api/scores?token=' + wowrepio_api_token).read)
lua_template_line = 'ns.DATABASE[%KEY%] = { average = %AVERAGE%, factors = { skill = %SKILL%, teamplay = %TEAMPLAY%, communication = %COM% } }'
to_be_lua_lines = {}
lua_lines = []

data.select do |record|
  record.values[0]['average'] != nil
end.each do |record|
  to_be_lua_lines[wowrepioHash(record.keys[0])] = record.values[0]
end

to_be_lua_lines.each do |k,v|
  lua_lines << lua_template_line.gsub('%KEY%', k.to_s).gsub('%AVERAGE%', '%.2f' % v['average']).gsub('%SKILL%', '%.2f' % v['skill']).gsub('%TEAMPLAY%', '%.2f' % v['teamplay']).gsub('%COM%', '%.2f' % v['communication'])
end

FileUtils.cp("./db/_db_template.lua", "./db/db.lua")
open('./db/db.lua', 'a') { |f|
  f.puts "\n"
  lua_lines.each{ |line| f.puts line }
}

out = `git status`
if out.include?("nothing to commit")
  puts "No changes; done!"

  return
end

system("git add .")
system("git commit -m'Update db.lua'")
if system("git push origin master")
  system("git tag #{Time.now.to_s.gsub(' ','').gsub('-', '').gsub(':', '')}")
  system("git push --tags")
end

puts "Done!"