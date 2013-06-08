#!/opt/local/bin/ruby1.9
require 'json'
require 'faye/websocket'
require 'eventmachine'
require 'serialport'
require './hardware/simulator.rb'
require './hardware/safecode-protobox.rb'

webservice_url = "http://localhost:4567/update"
serial_port = "/dev/tty.usbmodem621"

#box = SafeCode::Hardware::SafeCodeProtoBox.new :port => serial_port
box = SafeCode::Hardware::Simulator.new

EM.run {
  ws = Faye::WebSocket::Client.new(webservice_url)
  # block to check for new input and send it to the web service if it's complete
  EM::PeriodicTimer.new(1) do
    next if !box.connected? or !ws
    #puts "Checking box"
    box.each_event do |event|
      puts "sending event #{event[:event]} to webservice"
      ws.send event.to_json
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
