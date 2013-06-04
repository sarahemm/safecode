#!/opt/local/bin/ruby1.9
require 'json'
require 'faye/websocket'
require 'eventmachine'
require 'serialport'

webservice_url = "http://localhost:4567/update"
serial_port = "/dev/tty.usbmodem621"

box = SerialPort.new(serial_port, 9600, 8, 1, SerialPort::NONE)
box.read_timeout = -1 # nonblock
buf = ""
EM.run {
  ws = Faye::WebSocket::Client.new(webservice_url)
  #status = {:box_connected => true, :session_state => :not_in_session, :session_start => Time.now.to_i, :session_length => 2*60}

  EM::PeriodicTimer.new(1) do
    box.each_char do |data|
      buf += data
    end
    if(buf[-1] == '#') then
      code, length = buf[0..-2].split("*")
      cmd = Hash.new
      cmd[:event] = :check_in
      cmd[:code] = code
      cmd[:length] = length.to_i
      cmd[:distress] = false  # TODO: implement a distress code
      ws.send cmd.to_json
      puts "sending check-in request for #{length} minute session"
      buf = ""
    end
  end
  
#  EM::PeriodicTimer.new(2) do
#    next if !ws
#    p status
#    status[:last_daemon_contact] = Time.now.to_i
#    ws.send status.to_json
#    puts "sending update to webservice: #{status.to_json}"
#  end
  
  ws.on :open do |event|
    puts "websocket connection open"
  end
  
  ws.on :message do |event|
    p [:message, event.data]
  end
  
  ws.on :close do |event|
    puts "websocket connection closed, code #{event.code}, reason #{event.reason}"
    ws = nil
  end
}
