require 'open3'
require_relative 'top_1000_udp_ports'

HOST_DIR = './hosts'

def show_help
  puts <<-EOF
Network Scanner

Usage: ruby scan.rb <ip1> <ip2> <ip3>
Example: ruby scan.rb 192.168.0.1 192.168.0.2 192.168.0.3 > network_hosts.csv
EOF
end

def create_dirs(ip)
  stdout, stderr = Open3.capture2e("mkdir #{HOST_DIR}/#{ip}")
  stdout, stderr = Open3.capture2e("mkdir #{HOST_DIR}/#{ip}/scans")
end

def scan_hosts(ips)
  `mkdir #{HOST_DIR}`
  threads = []

  # 2. Scan each host for TCP ports
    start_tcp = Time.now

    ips.each do |ip|
      threads << Thread.new do
        create_dirs(ip)

        puts "Scanning #{ip} TCP ports..."
        start = Time.now
        stdout, stderr = Open3.capture2e("nmap --top-ports 1000 #{ip} --host-timeout 10m -sV -oG #{HOST_DIR}/#{ip}/scans/top_ports_tcp")
        endd = Time.now
        puts "#{ip} TCP Done in #{(endd - start).round(2)}s."
      end
    end

    # Wait until all the threads complete
    threads.each(&:join)
    end_tcp = Time.now

    puts "\n-------------------------------\nTCP scan done in #{(end_tcp - start_tcp).round(2)}s.\n-------------------------------\n\n"

  # 2. Scan each host for UDP ports
    start_udp = Time.now

    ips.each_with_index do |ip, i|
      create_dirs(ip)

      puts "Scanning #{ip} UDP ports..."
      start = Time.now
      stdout, stderr = Open3.capture2e("unicornscan -mU #{ip}:#{TOP_UDP_PORTS} > #{HOST_DIR}/#{ip}/scans/top_ports_udp")
      endd = Time.now
      puts "#{ip} UDP Done in #{(endd - start).round(2)}s. (#{i + 1}/#{ips.count})"
    end

    end_udp = Time.now
    puts "\n-------------------------------\nUDP scan done in #{(end_udp - start_udp).round(2)}s.\n-------------------------------\n\n"
end

def scan_to_csv
  ips = `ls -l hosts | awk '{print $9}' | awk /./`.split("\n")

  puts 'Host Name,Host IP,Port,Protocol,Service,State,Version,Vulnerabilities Found?,Notes'

  ips.each do |ip|
    tcp_scan_lines = File.read("#{HOST_DIR}/#{ip}/scans/top_ports_tcp").split("\n")
    udp_scan_lines = File.read("#{HOST_DIR}/#{ip}/scans/top_ports_udp").split("\n")

    puts ",#{ip},,,,"

    # TCP Ports:
    if tcp_scan_lines.any? { |line| line.include?('Status: Timeout') }
      puts ",,TIMEOUT,tcp,,"
    end

    tcp_scan_lines.each do |line|
      next unless line.include?('Ports: ')
      ports_line = line.match(/^.*[\t]Ports:\s(.*)[\t].*/).captures[0]
      ports = ports_line.split('/, ')

      ports.each do |port|
        id, state, protocol, service, version = port.match(/(\d+)\/(\w+)\/(\w+)\/\/(.+)\/\/(.*)/).captures
        puts ",,#{id},#{protocol},#{service},#{state},#{version}"
      end
    end

    # UDP Ports:
    udp_scan_lines.each do |line|
      line_parts = line.gsub("\t"," ").squeeze(" ").split(" ")
      id = line_parts[3].gsub(']', '')
      state = line_parts[1]
      protocol = line_parts[0].downcase
      service = line_parts[2].gsub('[', '')
      puts ",,#{id},#{protocol},#{service},#{state}"
    end
  end
end

if ARGV.any?
  ips = ARGV[1..-1]
  scan_hosts(ips)
  scan_to_csv
else
  show_help
end
