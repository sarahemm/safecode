#!/opt/local/bin/ruby1.9
require 'json'
require 'yaml'
require 'yubikey'
require 'statemachine'
require 'sinatra'
require 'sinatra/config_file'
require 'sinatra-websocket'

set :server, 'thin'
config_file '../safecode.yaml'
@@update_socket = nil
@@monitor_sockets = []
@@location = "Unknown"
@@box_connection = false
@@normal_code = "" # TODO: seems dirty
@@distress_code = "" # TODO: seems dirty

class SafeCodeContext
  attr_accessor :statemachine, :session_length, :session_start, :session_distress
  
  class AuthFailedError < SecurityError
  end
  
  def initialize
  end
  
  def initialize_session(length)
    puts "initializing new session"
    @session_start = Time.now.to_i
    @session_length = length
    @session_distress = false
    notify_monitors
  end
  
  def session_ended(code)
    puts "checking code #{code}"
    raise AuthFailedError if code != @@normal_code
    @session_start = @session_length = nil
    notify_monitors
  end

  def checked_in(code, length)
    puts "checking code #{code}"
    if(code == @@normal_code) then
      puts "code normal"      
      initialize_session(length)
      notify_monitors
    elsif(code == @@distress_code) then
      puts "code distress"
      initialize_session(length)
      @session_distress = true
      notify_monitors
    else
      puts "code bad"
      p code
      p @@normal_code
      
      raise AuthFailedError if code != @@normal_code
    end
  end
  
  def notify_monitors
    @@monitor_sockets.each do |sock|
      puts "sending update to monitor client #{sock}"
      status_update = Hash.new
      status_update[:session_state] = @statemachine.state
      status_update[:session_start] = @session_start;
      status_update[:session_length] = @session_length;
      status_update[:session_distress] = @session_distress;
      status_update[:location] = @@location;
      status_update[:daemon_connection] = (@@update_socket == nil ? false : true)
      status_update[:box_connection] = (@@update_socket == nil ? false : @@box_connection)
      if(@session_start != nil) then
        status_update[:time_until_checkin] = (@session_start + @session_length) - Time.now.to_i
      end
      sock.send status_update.to_json
    end
  end
end

@@fsm = Statemachine.build do
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
    on_entry  :notify_monitors
  end

  # initial state, event, destination state, handler to call
  trans :pre_checkin, :session_ended, :not_in_session, :session_ended
  trans :pre_checkin, :checked_in,    :in_session,     :checked_in 
  trans :in_session,  :session_ended, :not_in_session, :session_ended
  
  context SafeCodeContext.new
end

#set :yubikey_api_client, cfg['yubikey']['api_client']
#set :yubikey_api_key, cfg['yubikey']['api_key']
#set :yubikey_accepted_key, cfg['yubikey']['key_id']

# monitor connections from web browsers
get '/' do
  p settings.yubikey
  @@normal_code = settings.codes["normal"]
  @@distress_code = settings.codes["distress"]
  if !request.websocket?
    erb :index
  else
    EM::PeriodicTimer.new(5) do # TODO: configurable interval
      @@fsm.context.notify_monitors
    end
    request.websocket do |ws|
      ws.onopen do
        warn("monitor websocket opened")
        @@monitor_sockets << ws
      end
      ws.onmessage do |msg|
        puts "received location update"
        update = JSON.parse(msg, :symbolize_names => true)
        next if update[:token][0..11] != settings.yubikey['key_id']
        begin
          otp = Yubikey::OTP::Verify.new(:api_id => settings.yubikey['api_client'], :api_key => settings.yubikey['api_key'], :otp => update[:token])
          rescue Yubikey::OTP::InvalidOTPError
          next
        end
        if(otp.valid?) then
          puts "location update authenticated OK"
          @@location = update[:location] if otp.valid?
        else
          puts "location update authentication failed"
        end
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
  @@normal_code = settings.codes["normal"]
  @@distress_code = settings.codes["distress"]
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
        cmd = JSON.parse(msg, :symbolize_names => true)
        cmd_status = :ok
        begin
          case cmd[:event].to_sym
            when :keepalive
              @@box_connection = cmd[:box_connection]
            when :client_arrived
              @@fsm.client_arrived(1*60) # TODO: implement configurable first-check-in time
            when :check_in
              @@fsm.checked_in(cmd[:code], cmd[:length] * 60)
            when :check_out
              @@fsm.session_ended(cmd[:code])
            else
              puts "bad command received on update socket"
              cmd_status = :error
          end
        rescue SafeCodeContext::AuthFailedError
          cmd_status = :fail
        rescue Statemachine::TransitionMissingException
          cmd_status = :fail
        end
        response = Hash.new
        response[:status] = cmd_status
        response[:alert] = :checkin_missed if @@fsm.context.session_start and Time.now.to_i > @@fsm.context.session_start + @@fsm.context.session_length
        response[:distress] = @@fsm.context.session_distress
        response[:state] = @@fsm.state
        ws.send response.to_json
      end
      ws.onclose do
        warn("update websocket closed")
        @@update_socket = nil
      end
    end
  end
end
