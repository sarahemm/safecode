#!/opt/local/bin/ruby1.9
require 'json'
require 'statemachine'
require 'sinatra'
require 'sinatra-websocket'

set :server, 'thin'
@@update_socket = nil
@@monitor_sockets = []
@@location = "Unknown"

class SafeCodeContext
  attr_accessor :statemachine, :session_length, :session_start
  
  class AuthFailedError < SecurityError
  end
  
  def initialize
  end
  
  def initialize_session(length)
    puts "initializing new session"
    @session_start = Time.now.to_i
    @session_length = length
    notify_monitors
  end
  
  def session_ended(code)
    puts "checking code #{code}"
    raise AuthFailedError if code != "1212"  # TODO: configurable code
    notify_monitors
  end

  def checked_in(code, length)
    puts "checking code #{code}"
    raise AuthFailedError if code != "1212"  # TODO: configurable code
    initialize_session(length)
    notify_monitors
  end
  
  def notify_monitors
    puts "notifying monitors of transition to #{@statemachine.state}"
    @@monitor_sockets.each do |sock|
      puts "sending update to monitor client"
      status_update = Hash.new
      status_update[:session_state] = @statemachine.state
      status_update[:session_start] = @session_start;
      status_update[:session_length] = @session_length;
      status_update[:daemon_connection] = (@@update_socket == nil ? false : true)
      if(@session_start != nil) then
        status_update[:time_until_checkin] = (@session_start + @session_length) - Time.now.to_i
      end
      sock.send status_update.to_json
    end
  end
end

fsm = Statemachine.build do
  state :not_in_session do
    event     :client_arrived,  :pre_checkin
    on_entry  :notify_monitors
  end
  state :pre_checkin do
    event     :checked_in,      :in_session
    event     :session_ended,   :not_in_session
    on_entry  :initialize_session
  end
  state :in_session do
    event     :session_ended,   :not_in_session
    on_entry  :checked_in
  end

  trans :pre_checkin, :session_ended, :not_in_session, :session_ended  
  trans :in_session,  :session_ended, :not_in_session, :session_ended
  
  context SafeCodeContext.new
end

set :fsm, fsm

# monitor connections from web browsers
get '/' do
  if !request.websocket?
    erb :index
  else
    EM::PeriodicTimer.new(5) do # TODO: configurable interval
      puts "sending update to monitor client"
      settings.fsm.context.notify_monitors
    end
    request.websocket do |ws|
      ws.onopen do
        warn("monitor websocket opened")
        @@monitor_sockets << ws
      end
      ws.onmessage do |msg|
        puts "received location update"
        update = JSON.parse(msg, :symbolize_names => true)
        # TODO: auth
        @@location = update[:location]
      end
      ws.onclose do
        warn("monitor websocket closed")
        @@monitor_sockets.delete(ws)
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
        # TODO: add protection against a second connection overriding the first
        warn("update websocket opened")
        @@update_socket = ws
      end
      ws.onmessage do |msg|
        puts "received update"
        cmd = JSON.parse(msg, :symbolize_names => true)
        cmd_status = :ok
        begin
          case cmd[:event].to_sym
            when :client_arrived
              settings.fsm.client_arrived(1*60) # TODO: implement configurable first-check-in time
            when :check_in
              settings.fsm.checked_in(cmd[:code], cmd[:length] * 60)
            when :check_out
              settings.fsm.session_ended(cmd[:code])
            else
              puts "bad command received on update socket"
              cmd_status = :error
          end
        rescue SafeCodeContext::AuthFailedError
          cmd_status = :fail
        end
        response = Hash.new
        response[:status] = cmd_status
        response[:state] = settings.fsm.state
        p response.to_json
        ws.send response.to_json
      end
      ws.onclose do
        warn("update websocket closed")
        @@update_socket = nil
      end
    end
  end
end
