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
        return if buf[-1] != 'E' && buf[-1] != 'X'
        event = Hash.new
        if(buf == "E") then
          event[:event] = :client_arrived
          @event_queue << event
        elsif(buf[-1] == "X") then
          code = buf[0..-2]
          event[:event] = :check_out
          event[:code] = code
          @event_queue << event
        else
          code, length = buf[0..-2].split("?")
          event[:event] = :check_in
          event[:code] = code
          event[:length] = length.to_i
          @event_queue << event
        end
        @buf = ""
      end
      
      def set_lighting(lighting)
        #@box.print (lighting.includes?(:red)   ? "R" : "r")
        #@box.print (lighting.includes?(:green) ? "G" : "g")
        #@box.print (lighting.includes?(:blue)  ? "B" : "b")
        #true
        false
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