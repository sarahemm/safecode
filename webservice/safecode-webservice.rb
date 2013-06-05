#!/opt/local/bin/ruby1.9
require 'json'
require 'sinatra'
require 'sinatra-websocket'

set :server, 'thin'
set :monitor_sockets, []
set :update_socket, nil
set :status, {}

# monitor connections from web browsers
get '/' do
  if !request.websocket?
    erb :index
  else
    EM::PeriodicTimer.new(5) do # TODO: configurable interval
      settings.monitor_sockets.each do |sock|
        puts "sending update to monitor client"
        full_status = settings.status
        full_status[:daemon_connection] = (settings.update_socket == nil ? false : true)
        if(full_status[:session_state] && (full_status[:session_state].to_sym == :pre_checkin || full_status[:session_state].to_sym == :in_session)) then
          full_status[:time_until_checkin] = (full_status[:session_start] + full_status[:session_length]) - Time.now.to_i
        end
        sock.send full_status.to_json
      end
    end
    request.websocket do |ws|
      ws.onopen do
        warn("monitor websocket opened")
        settings.monitor_sockets << ws
      end
      ws.onmessage do |msg|
        warn("message received from monitor websocket, ignored")
      end
      ws.onclose do
        warn("monitor websocket closed")
        settings.monitor_sockets.delete(ws)
      end
    end
  end
end

# update connections from the daemon
get '/update' do
  if !request.websocket?
    request.close
  else
    request.websocket do |ws|
      ws.onopen do
        warn("update websocket opened")
        settings.update_socket = ws
      end
      ws.onmessage do |msg|
        puts "received update"
        cmd = JSON.parse(msg, :symbolize_names => true)
        case cmd[:event].to_sym
          when :client_arrived
            settings.status[:session_state] = :pre_checkin
            settings.status[:session_start] = Time.now.to_i
            settings.status[:session_length] = 5*60 # TODO: implement configurable first-check-in time
          when :check_in
            if(cmd[:code] == "1212") then # TODO: implement code configuration
              settings.status[:session_state] = :in_session
              settings.status[:session_start] = Time.now.to_i
              settings.status[:session_length] = cmd[:length] * 60
              puts "check-in ok"
            else
              puts "check-in request failed, bad code"
              # TODO: implement failure
            end
          when :check_out
            if(cmd[:code] == "1212") then # TODO: implement code configuration
              settings.status[:session_state] = :not_in_session
              puts "check-out ok"
            else
              puts "check-out request failed, bad code"
              # TODO: implement failure
            end
          else
            puts "bad command received on update socket"
        end
      end
      ws.onclose do
        warn("update websocket closed")
        settings.update_socket = nil
      end
    end
  end
end
