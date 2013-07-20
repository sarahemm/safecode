# SafeCode Box

# Buttons
# -------
# Storm 6000 (0-9, *, #, ENTER, CLEAR, ?, CANCEL)

# Lighting
# --------
# RGB

# Audio
# --------
# Piezo buzzer element

# Actions
# ENTER - client arrived
# <code>?<length>ENTER - log into session
# <code>CLEAR - cancel/finish session
# CANCEL - forget anything entered since last command

module SafeCode
  class Hardware
    class SafeCodeBox
      def initialize(args)
        @serial_port = args[:port]
        @buf = ""
        @event_queue = Array.new
        connect
      end
      
      def connect
        return true if @box != nil
        puts "no connection to SafeCode box, reconnecting..."
        begin
          @box = SerialPort.new(@serial_port, 9600, 8, 1, SerialPort::NONE)
          @box.read_timeout = -1 # nonblock
          puts "reconnected to SafeCode box"
        rescue Errno::ENOENT
          puts "box not plugged in"
          false
        end
        true
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
          @box.each_char do |data|
            @buf += data
          end
        rescue Errno::ENXIO, NoMethodError
          @box = nil
          return false
        end
        true
      end
      
      def events
        get_data
        process_events
        @event_queue
      end
      
      def process_events
        if(@buf[-1] == 'X') then
          @buf = ""
          return
        end
        event = Hash.new
        if(@buf == "E") then
          event[:event] = :client_arrived
          @event_queue << event
          @buf = ""
        elsif(@buf[-1] == "C") then
          code = @buf[0..-2]
          event[:event] = :check_out
          event[:code] = code
          @event_queue << event
          @buf = ""
        elsif(@buf[-1] == "E") then
          code, length = @buf[0..-2].split("?")
          event[:event] = :check_in
          event[:code] = code
          event[:length] = length.to_i
          @event_queue << event
          @buf = ""
        end
      end
      
      def status=(lighting)
        return false if @box == nil
        @box.print (lighting.include?(:red)   | lighting.include?(:white) | lighting.include?(:yellow) ? "R" : "r")
        @box.print (lighting.include?(:green) | lighting.include?(:white) | lighting.include?(:yellow) ? "G" : "g")
        @box.print (lighting.include?(:blue)  | lighting.include?(:white) ? "B" : "b")
      end
      
      def alert=(sound)
        return false if @box == nil
        @box.print (sound == nil ? 'x' : 'X')
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