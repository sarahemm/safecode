# SafeCode Box Simulator

# Buttons (use keyboard)
# -------
# Telephone Keypad (0-9, *, #)
# E ENTER
# C CLEAR
# ? HELP
# X CANCEL

# Lighting
# --------
# none yet

require 'term/ansicolor'
include Term::ANSIColor

module SafeCode
  class Hardware
    class Simulator
      def initialize(args = {})
        @buf = ""
        @event_queue = Array.new
      end
      
      def each_event
        get_data
        process_events
        while(!@event_queue.empty?) do
          yield @event_queue.shift
        end
      end
      
      def get_data
        begin
          STDIN.read_nonblock(255).each_char do |data|
            @buf += data.strip
          end
        rescue Errno::EAGAIN
          # no data waiting, which is fine
        end
        true
      end
      
      def process_events
        buf = @buf.upcase
        if(buf[-1] == 'X') then
          buf = ""
          return
        end
        event = Hash.new
        if(buf == "E") then
          event[:event] = :client_arrived
          @event_queue << event
          @buf = ""
        elsif(@buf[-1] == "C") then
          code = buf[0..-2]
          event[:event] = :check_out
          event[:code] = code
          @event_queue << event
          @buf = ""
        elsif(buf[-1] == "E") then
          code, length = buf[0..-2].split("?")
          event[:event] = :check_in
          event[:code] = code
          event[:length] = length.to_i
          @event_queue << event
          @buf = ""
        end
      end
      
      def events
        get_data
        process_events
        @event_queue
      end
      
      def status=(lighting)
        print red, bold,    "RED",    reset, "\n" if lighting.include? :red
        print green, bold,  "GREEN",  reset, "\n" if lighting.include? :green
        print blue, bold,   "BLUE",   reset, "\n" if lighting.include? :blue
        print yellow, bold, "YELLOW", reset, "\n" if lighting.include? :yellow
        true
      end
      
      def alert=(sound)
        puts "ALERT '#{sound}'\007" if sound
        true
      end
      
      def set_text
        false
      end
      
      def connected?
        true
      end
    end
  end
end