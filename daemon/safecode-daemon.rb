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

  # block to check for new input and send it to the web service if it's complete
  EM::PeriodicTimer.new(1) do
    next if !box or !ws
    begin
      box.each_char do |data|
        buf += data
      end
    rescue Errno::ENXIO
      puts "lost connection to SafeCode box"
      box = nil
      next
    end
    puts "Checking box"
    if(buf[-1] == '#') then
      cmd = Hash.new
      if(buf == "*#") then
        cmd[:event] = :client_arrived
        ws.send cmd.to_json
        puts "sending client-arrived request"
      elsif(buf[-2..-1] == "*#") then
        code = buf[0..-3]
        cmd[:event] = :check_out
        cmd[:code] = code
        p cmd
        ws.send cmd.to_json
        puts "sending check-out request"
      else
        code, length = buf[0..-2].split("*")
        cmd[:event] = :check_in
        cmd[:code] = code
        cmd[:length] = length.to_i
        cmd[:distress] = false  # TODO: implement a distress code
        ws.send cmd.to_json
        puts "sending check-in request for #{length} minute session"
      end
      buf = ""
    end
  end
  
  # block to check for lost connections and attempt reconnection
  EM::PeriodicTimer.new(5) do
    if(!box) then
      puts "no connection to SafeCode box, reconnecting..."
      begin
        box = SerialPort.new(serial_port, 9600, 8, 1, SerialPort::NONE)
        box.read_timeout = -1 # nonblock
        puts "reconnected to SafeCode box"
      rescue Errno::ENOENT
        puts "box not plugged in"
      end
    end
  end
  
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
