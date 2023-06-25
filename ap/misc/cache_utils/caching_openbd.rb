#!/usr/bin/env ruby

require 'sequel'
require 'date'
require 'logger'
require 'json'
require_relative 'util'
require_relative '../../modules/openbd'
require_relative '../../modules/selfdb'
require_relative '../../secret'

module CacheUtil
	def self.caching_openbd(cache_dir, option)
		SelfDB.setup DB_NAME, host: DB_HOST, user: DB_USER, password: DB_PWD

		coverage = OpenBD.coverage
		puts "All coverage books: #{coverage.length}"

		@error = Logger.new 'error.log'

		def self.insert_bookdata(book)
			return unless book.has_key? :isbn
			begin
				SelfDB::Book.register_core book[:isbn], book, update: true
			rescue => e
				@error << e.full_message
				@error << JSON.dump(book)
			end
		end

		with_cover = option == 'with-cover'
		total_book = coverage.length

		result = OpenBD.gets(coverage) do |books|
			books.each do |book|
				print "#{total_book}\r"
				total_book -= 1
				next if book.nil?
				insert_bookdata book
				next unless with_cover && book.has_key?(:cover)
				load_image book[:isbn], book[:cover], cache_dir
			end
		end

		today = Date.today
		add_data = SelfDB::BookData.dataset.where(:created_at => today).count
		update_data = SelfDB::BookData.dataset.where(:modified_at => today).where(Sequel.expr(:created_at) < today).count
		remove_data = SelfDB::BookData.dataset.where(Sequel.expr(:modified_at) < today).count

		if result[:succeed] == result[:total]
			puts "All Succeed."
		else
			puts "Succeed: #{result[:succeed]}/#{result[:total]}"
		end
		puts "add: #{add_data}, update: #{update_data}, remove: #{remove_data}"
	end
end