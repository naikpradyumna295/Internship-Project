#!/usr/bin/env ruby
require_relative '../../secret'

return unless File.writable? CACHE_DIR

def is_jpg(path)
	soi, app0, length, id, version, units, x_density, y_density, x_thumbnail, y_thumbnail = IO.binread(path, 20).unpack('S! S! S! A5 S! C S! S! C C')
	return false unless soi == 0xD8FF
	return false unless app0 == 0xE0FF
	return false unless id == 'JFIF'
	return true
end

Dir.glob(File.join(CACHE_DIR, "*")) do |path|
	next if File.basename(path) == 'noimage.png'
	next if is_jpg(path)
	puts "delete: #{path}"
	File.delete path
end
