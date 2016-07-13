ruby-bmp085
===========
I2Cで気圧や温度を測ることの出来るBMP085をRaspberry Pi上で取得するRubyスクリプトです。
殆ど中身は[Adafruit BMP085 Library](https://github.com/adafruit/Adafruit-BMP085-Library)からの移植で、
温度と気圧の取得のみを実装しています。

## 依存関係
以下のgemに依存しています。
[i2c-devices](https://github.com/cho45/ruby-i2c-devices)
```
$ gem install i2c-devices
```

## 使い方
```ruby
require './bmp085'

# i2cデバイスのパス渡す
bmp085 = BMP085.new('/dev/i2c-1')

# 温度の取得
bmp085.read_temperature

# 気圧の取得
bmp085.read_pressure
```

