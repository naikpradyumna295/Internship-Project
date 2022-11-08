#!/usr/bin/env ruby

require 'uri'
require 'net/http'
require_relative '../../modules/selfdb'
require_relative '../../modules/openbd'
require_relative '../../modules/rakuten_books'
require_relative '../../secret'

SelfDB.setup DB_NAME, user: DB_USER, password: DB_PWD
RaktenBooksAPI.setup RAKUTEN_APP_ID

coverage = SelfDB::BookData.select(:isbn).use_cursor.map {|book| book[:isbn].to_i}.join(",")
puts "All coverage books: #{coverage.length}"

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

to_rakuten_books = []

OpenBD.get(coverage).each do |book|
	next if book.nil?
	if !book.has_key?(:cover)
		to_rakuten_books.append book[:isbn]
	else
		load_image book[:isbn], book[:cover]
	end
end

puts "From rakuten books: #{to_rakuten_books.length}"

def from_rakuten(isbn)
	book = RaktenBooksAPI.get({:isbn => isbn})
	return if book.nil? || book.length != 1
	book = book[0]
	return unless book.has_key?(:cover)
	load_image isbn, book[:cover]
end

th = Thread.new do
	to_rakuten_books.each do |isbn|
		from_rakuten isbn
		sleep 5
	end
end
th.join
