#!/opt/local/bin/ruby1.9
require 'json'
require 'faye/websocket'
require 'eventmachine'

webservice_url = "http://localhost:4567/update"

EM.run {
  ws = Faye::WebSocket::Client.new(webservice_url)
  status = {:box_connected => true, :session_state => :in_session, :session_start => Time.now.to_i, :session_length => 2*60}
  
  EM::PeriodicTimer.new(2) do
    next if !ws
    p status
    status[:last_daemon_contact] = Time.now.to_i
    ws.send status.to_json
    puts "sending update to webservice: #{status.to_json}"
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