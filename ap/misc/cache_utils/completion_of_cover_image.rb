require_relative 'util'
require_relative '../../modules/selfdb'
require_relative '../../modules/openbd'
require_relative '../../modules/rakuten_books'
require_relative '../../secret'

module CacheUtil
	def self.completion_of_cover_image(cache_dir)
		SelfDB.setup DB_NAME, user: DB_USER, password: DB_PWD
		RaktenBooksAPI.setup RAKUTEN_APP_ID
		
		coverage = SelfDB::UserBooks.order(:isbn).distinct(:isbn).select(:isbn).all.map{|book| book[:isbn].to_i}
		puts "All coverage books: #{coverage.length}"

		to_rakuten_books = []

		OpenBD.gets(coverage) do |books|
			books.each do |book|
				next if book.nil?
				print "#{book[:isbn]}\r"
				if !book.has_key?(:cover)
					to_rakuten_books.append book[:isbn]
				else
					load_image book[:isbn], book[:cover], cache_dir
				end
			end
		end

		if RaktenBooksAPI.setup?
			puts "From rakuten books: #{to_rakuten_books.length}"

			def self.from_rakuten(isbn, cache_dir)
				book = RaktenBooksAPI.get({:isbn => isbn})
				return if book.nil? || book.length != 1
				book = book[0]
				return unless book.has_key?(:cover)
				load_image isbn, book[:cover], cache_dir
			end

			to_rakuten_books.each do |isbn|
				print "#{isbn}\r"
				from_rakuten isbn, cache_dir
				sleep 5
			end
		end
	end
end
