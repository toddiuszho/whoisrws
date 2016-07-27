require 'json'
require 'http'
require 'faraday'
require_relative 'vash'

skips = ['American Registry for Internet Numbers', 'Various Registries (Maintained by ARIN)']
vash = Vash.new
conn = Faraday.new 

ARGV.each do |ip|
  if vash.key?(ip)
    name = vash[ip]
    puts "Retrieved [#{ip}] = [#{name}] from [cache]."
    next
  end

  response = conn.get do |req|
    req.url "https://whois.arin.net/rest/nets;q=#{ip}", :showDetails => true
    req.headers['Accept'] = 'application/json'
  end

  doc = JSON.parse(response.body)
  nets = doc['nets']['net']
  nets.each do |net|
    name = net['orgRef']['@name']
    unless skips.include?(name)
      vash[ip, 3600] = name
    end
  end

  puts "Retrieved [#{ip}] = [#{name}] from [web service]."
end
