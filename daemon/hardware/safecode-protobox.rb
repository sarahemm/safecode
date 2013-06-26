# SafeCode Prototype Box (Arduino w/ TouchShield)

# Buttons
# -------
# Telephone Keypad (0-9, *, #)

# Lighting
# --------
# none

# Actions
# # - client arrived
# <code>*<length># - log into session
# <code>*# - cancel/finish session

module SafeCode
  class Hardware
    class SafeCodeProtoBox
      def initialize(args)
        @serial_port = args[:port]
        @buf = ""
        @event_queue = Array.new
        connect
      end
      
      def connect
        return true if @box != nil
        #puts "no connection to SafeCode box, reconnecting..."
        begin
          box = SerialPort.new(serial_port, 9600, 8, 1, SerialPort::NONE)
          box.read_timeout = -1 # nonblock
          #puts "reconnected to SafeCode box"
        rescue Errno::ENOENT
          #puts "box not plugged in"
          false
        end
        true
      end
      
      def each_event
        event_queue.each do |event|
          yield event
        end
      end
      
      def get_data
        begin
          box.each_char do |data|
            @buf += data
          end
        rescue Errno::ENXIO
          box = nil
          return false
        end
        true
      end
      
      def process_events
        return if buf[-1] != '#'
        event = Hash.new
        if(buf == "#") then
          event[:event] = :client_arrived
          @event_queue << event
        elsif(buf[-2..-1] == "*#") then
          code = buf[0..-3]
          event[:event] = :check_out
          event[:code] = code
          @event_queue << event
        else
          code, length = buf[0..-2].split("*")
          event[:event] = :check_in
          event[:code] = code
          event[:length] = length.to_i
          @event_queue << event
        end
        buf = ""
      end
      
      def events
        get_data
        process_events
        @event_queue
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
        return !(@box == nil)
      end
    end
  end
end