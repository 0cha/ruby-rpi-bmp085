require 'i2c'
require 'i2c/driver/i2c-dev'

class BMP085
  attr_accessor :ac1, :ac2, :ac3, :ac4, :ac5, :ac6, :b1, :b2, :mb, :mc, :md
  # BMP085 default address.
  I2CADDR           = 0x77

  # Operating Modes
  ULTRALOWPOWER     = 0
  STANDARD          = 1
  HIGHRES           = 2
  ULTRAHIGHRES      = 3

  # Registers
  CAL_AC1           = 0xAA  # R   Calibration data (16 bits)
  CAL_AC2           = 0xAC  # R   Calibration data (16 bits)
  CAL_AC3           = 0xAE  # R   Calibration data (16 bits)
  CAL_AC4           = 0xB0  # R   Calibration data (16 bits)
  CAL_AC5           = 0xB2  # R   Calibration data (16 bits)
  CAL_AC6           = 0xB4  # R   Calibration data (16 bits)
  CAL_B1            = 0xB6  # R   Calibration data (16 bits)
  CAL_B2            = 0xB8  # R   Calibration data (16 bits)
  CAL_MB            = 0xBA  # R   Calibration data (16 bits)
  CAL_MC            = 0xBC  # R   Calibration data (16 bits)
  CAL_MD            = 0xBE  # R   Calibration data (16 bits)
  CONTROL           = 0xF4
  TEMPDATA          = 0xF6
  PRESSUREDATA      = 0xF6

  # Commands
  READTEMPCMD       = 0x2E
  READPRESSURECMD   = 0x34

  def initialize(path, mode=STANDARD, debug=false)
    @device = I2CDevice.new(address: I2CADDR, drive: I2CDevice::Driver::I2CDev.new(path))
    @debug = debug
    @mode  = mode
    load_calibration_data
  end

  def load_calibration_data
    self.ac1 = readS16BE(CAL_AC1)
    self.ac2 = readS16BE(CAL_AC2)
    self.ac3 = readS16BE(CAL_AC3)
    self.ac4 = readU16BE(CAL_AC4)
    self.ac5 = readU16BE(CAL_AC5)
    self.ac6 = readU16BE(CAL_AC6)
    self.b1 = readS16BE(CAL_B1)
    self.b2 = readS16BE(CAL_B2)
    self.mb = readS16BE(CAL_MB)
    self.mc = readS16BE(CAL_MC)
    self.md = readS16BE(CAL_MD)
    if @debug
      puts "ac1: #{ac1}"
      puts "ac2: #{ac2}"
      puts "ac3: #{ac3}"
      puts "ac4: #{ac4}"
      puts "ac5: #{ac5}"
      puts "ac6: #{ac6}"
      puts "b1: #{b1}"
      puts "b2: #{b2}"
      puts "mb: #{mb}"
      puts "mc: #{mc}"
      puts "md: #{md}"
    end
  end

  def read_raw_temperature
    writeU8(CONTROL, READTEMPCMD)
    sleep(0.005)
    raw = readU16BE(TEMPDATA)
    return raw
  end
  
  def read_temperature
    ut = read_raw_temperature
    x1 = ((ut - self.ac6) * self.ac5) >> 15
    x2 = (self.mc << 11) / (x1 + md)
    b5 = x1 + x2
    temp = ((b5 + 8) >> 4) / 10.0
    return temp
  end

  def read_raw_pressure
    writeU8(CONTROL, READPRESSURECMD + (@mode << 6))
    case @mode
    when ULTRALOWPOWER
      sleep(0.005)
    when HIGHRES
      sleep(0.014)
    when ULTRAHIGHRES
      sleep(0.026)
    else
      sleep(0.008)
    end

    msb  = readU8(PRESSUREDATA)
    lsb  = readU8(PRESSUREDATA+1)
    xlsb = readU8(PRESSUREDATA+2)

    raw = ((msb << 16) + (lsb << 8) + xlsb) >> (8 - @mode)

    return raw
  end

  def read_pressure
    ut = read_raw_temperature
    up = read_raw_pressure
    
    x1 = ((ut - self.ac6) * self.ac5) >> 15
    x2 = (self.mc << 11) / (x1 + self.md)
    b5 = x1 + x2

    b6 = b5 - 4000
    x1 = (self.b2 * (b6 * b6) >> 12) >> 11
    x2 = (self.ac2 * b6) >> 11
    x3 = x1 + x2

    b3 = (((self.ac1 * 4 + x3) << @mode) + 2) / 4
    x1 = (self.ac3 * b6) >> 13
    x2 = (self.b1 * ((b6 * b6) >> 12)) >> 16
    x3 = ((x1 + x2) + 2) >> 2

    b4 = (self.ac4 * (x3 + 32768)) >> 15
    
    b7 = (up - b3) * (50000 >> @mode)
    if b7 < 0x80000000
      p = (b7 * 2) / b4
    else
      p = (b7 / b4) * 2
    end

    x1 = (p >> 8) * (p >> 8)
    x1 = (x1 * 3038) >> 16
    x2 = (-7357 * p) >> 16

    p = p + ((x1 + x2 + 3791) >> 4)
    
    if @debug
      puts "b5 = #{b5}"
      puts "b6 = #{b6}"
      puts "b3 = #{b3}"
      puts "b4 = #{b4}"
      puts "b7 = #{b7}"
      puts "pressure #{p} Pa"
    end
    
    return p
  end
  
  private
  
  def writeU8(register,param)
    @device.i2cset(register,param, 1)
  end
  
  def readU8(register)
    result = @device.i2cget(register,1).bytes.first
    return result
  end
  
  def readU16(register, big_endian=true)
    read_data = @device.i2cget(register,2).bytes
    
    value = read_data # big endian
    unless big_endian
      value = read_data.reverse
    end
    
    result = eval("0x#{value.map{|r| r.to_s(16)}.join}")
    return result
  end

  def readS16(register, bit_endian)
    result = readU16(register, bit_endian)
    result -= 65536 if result > 32767
    return result
  end

  def readS16BE(register)
    result = readS16(register, true)
    return result
  end

  def readU16BE(register)
    result =readU16(register, true)
    return result
  end
  
end
