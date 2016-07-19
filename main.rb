$:.unshift File.dirname(__FILE__)

require 'bmp085'
require 'unimidi'

# BMP085 sampling mode
#  ULTRALOWPOWER = 0
#  STANDARD      = 1
#  HIGHRES       = 2
#  ULTRAHIGHRES  = 3

bmp085 = BMP085.new('/dev/i2c-1', 3)

#bmp085.read_temperature

output = UniMIDI::Output.use(:first)
duration= 0.1
filter = []
20.times do
  pressure = bmp085.read_pressure
  puts pressure
  filter << pressure
end

filter = filter.inject{|data,sum| sum += data } / 20
puts "filter: #{filter}"
loop do

  pressure =  (bmp085.read_pressure - filter) / 11
  puts pressure
  pressure = 127 if pressure > 127
  if 0.0 < pressure 
    output.puts(0xB0, 1, pressure)
    sleep(duration)
  end
  
end
