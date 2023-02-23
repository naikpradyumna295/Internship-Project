require 'digest'
require 'uri'
require 'net/http'

module CacheUtil
	class << self
		def is_jpg(data)
			soi, app0, length, id, version, units, x_density, y_density, x_thumbnail, y_thumbnail = data[..20].unpack('S! S! S! A5 S! C S! S! C C')
			soi == 0xD8FF && app0 == 0xE0FF && id == 'JFIF'
		end

		def empty_image?(data); data.size == 3185 && Digest::SHA256.hexdigest(data) == '56ef1a38d5ba7980f1a6c08926c931d0feaa12fd837e62d861373921670c3592'; end

		def load_image(isbn, cover, cache_dir)
			return unless File.writable?(cache_dir)
			uri = URI.parse(cover)
			ext = File.extname(uri.path)
			return unless ext == '.jpg' || ext == '.jpeg'
			cover_name = File.join(cache_dir, "#{isbn}.jpg")
			return if File.exist?(cover_name)

			data = Net::HTTP.get(uri)
			return if !is_jpg(data) || empty_image?(data)

			puts "caching: #{cover_name}"
			File.write(cover_name, data)
		end
	end
end
