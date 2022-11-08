#!/usr/bin/env ruby

require 'sequel'
require 'date'
require 'logger'
require 'json'
require_relative '../modules/openbd'
require_relative '../modules/selfdb'
require_relative '../secret'

SelfDB.setup DB_NAME, user: DB_USER, password: DB_PWD

coverage = OpenBD.coverage
puts "All coverage books: #{coverage.length}"

$error = Logger.new 'error.log'

def insert_bookdata(book)
	return unless book.has_key? :isbn
	begin
		SelfDB::Book.register_core book[:isbn], book, update: true
	rescue => e
		$error << e.full_message
		$error << JSON.dump(book)
	end
end

def load_image(isbn, cover)
	return unless File.writable?(CACHE_DIR)
	uri = URI.parse(cover)
	ext = File.extname(uri.path)
	return unless ext == '.jpg' || ext == '.jpeg'
	cover_name = File.join(CACHE_DIR, "#{isbn}.jpg")
	return if File.exist?(cover_name)

	data = Net::HTTP.get(uri)
	soi, app0, length, id = data[..11].unpack('S! S! S! A5')
	return unless soi == 0xD8FF
	return unless app0 == 0xE0FF
	return unless id == 'JFIF'
	puts "caching: #{cover_name}"
	File.write(cover_name, data)
end

no_cover = ARGV.include? '-nocover'
total_book = coverage.length

result = OpenBD.gets(coverage) do |books|
	books.each do |book|
		print "#{total_book}\r"
		total_book -= 1
		next if book.nil?
		insert_bookdata book
		next if no_cover
		next unless book.has_key? :cover
		load_image book[:isbn], book[:cover]
	end
end

today = Date.today
add_data = SelfDB::BookData.dataset.where(:created_at => today).count
remove_data = SelfDB::BookData.dataset.where(Sequel.expr(:modified_at) < today).count

if result[:succeed] == result[:total]
	puts "All Succeed."
else
	puts "Succeed: #{result[:succeed]}/#{result[:total]}"
end
puts "add: #{add_data}, remove: #{remove_data}"