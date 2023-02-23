require_relative 'util'

module CacheUtil
	def self.remove_unsupport_format(cache_dir)
		Dir.glob(File.join(cache_dir, "*")) do |path|
			print "#{path}\r"
			next if File.basename(path) == 'noimage.png'
			data = IO.binread(path)
			next if is_jpg(data) && !empty_image?(data)
			puts "delete: #{path}"
			File.delete path
		end
	end
end