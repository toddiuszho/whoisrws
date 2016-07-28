require 'json'
require 'http'
require 'faraday'
require_relative 'vash'

# Setup
skips = ['American Registry for Internet Numbers', 'Various Registries (Maintained by ARIN)']
vash = Vash.new
conn = Faraday.new
debugging = false

ARGV.each do |ip|
  # Cache hit detection
  if vash.key?(ip)
    names = vash[ip]
    puts "Retrieved [#{ip}] = [#{names}] from [cache]."
    next
  end

  begin
    # Call
    response = conn.get do |req|
      req.url "https://whois.arin.net/rest/nets;q=#{ip}", :showDetails => true
      req.headers['Accept'] = 'application/json'
    end

    # Nil?
    if response.nil?
      puts "Response is nil!"
      next
    end

    # Bad status
    if response.status != 200
      puts "Couldn't retrieve [#{ip}] with status [#{response.status}]!"
      next
    end

    # Parse
    doc = JSON.parse(response.body)

    # Bad forms
    if debugging
      if doc.nil?
        puts "Nil doc"
        next
      end
      unless doc['nets']
        puts "doc = #{doc}"
        next
      end
      unless doc['nets']['net']
        puts "nets = #{doc['nets']}"
        next
      end
    end

    # Readin' and cachin'!
    nets = doc['nets']['net']
    nets.each do |net|

      if debugging
        unless net['orgRef'] || net['customerRef']
          puts JSON.pretty_generate(net).gsub(":", " =>")
          next
        end
      end

      # orgRef OR customerRef
      if net.key?('orgRef')
        name = net['orgRef']['@name']
      else
        name = net['customerRef']['@name']
      end

      unless skips.include?(name)
        if vash.key?(ip)
          vash[ip, 3600] = vash[ip].push(name)
        else
          vash[ip, 3600] = [name]
        end
      end
    end

    # Report
    if vash.key?(ip)
      a = vash[ip].sort.uniq
      puts "Retrieved [#{ip}] = [#{a}] from [web service]."
    end
  rescue Exception => e
    puts "Couldn't retrieve [#{ip}] with exception [#{e}]!"
  end
end
