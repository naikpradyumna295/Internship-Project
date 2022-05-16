require 'uri'
require 'json'
require 'net/http'

module RaktenBooksAPI
	@@DefaultQueryParams = {
		:formatVersion => 2,
		:outOfStockFlag => 1
	}

	class << self
		def setup(application_id, affiliate_id: nil)
			@@DefaultQueryParams[:applicationId] = application_id
			@@DefaultQueryParams[:affiliateId] = affiliate_id unless affiliate_id.nil?
		end

		def setup?; @@DefaultQueryParams.has_key? :applicationId; end
		def affiliateId=(id); @@DefaultQueryParams[:affiliateId] = id unless id.nil?; end

		def get(param)
			raise 'Need application id.' unless setup?

			params = @@DefaultQueryParams.clone.merge(param)
			query = params.map{|k,v| "#{k}=#{URI.encode_www_form_component(v)}" }.join('&')

			uri = URI.parse "https://app.rakuten.co.jp/services/api/BooksBook/Search/20170404?#{query}"
			book_data = JSON.parse(Net::HTTP.get(uri), symbolize_names: true)

			# pp book_data

			raise "[#{book_data[:error]}] #{book_data[:error_description]}" unless book_data.has_key?(:Items)
			book_data[:Items].map {|data| json2book(data)}.delete_if{|v| v.nil?}
		rescue => e
			puts e.message
			return []
		end

		private
		
		def json2book(data)
			return nil unless data[:isbn].match /97[89][0-9]{10}/
			{
				:isbn => data[:isbn].to_i,
				:from => -1,
				:書籍名 => title(data),
				:レーベル => data[:seriesName],
				:著者 => data[:author],
				:著者（読み） => data[:authorKana],
				:価格 => data[:itemPrice].to_i,
				:判型 => data[:size],
				:出版社 => data[:publisherName],
				:発売日 => sales_date(data),
				:説明 => data[:itemCaption],
				:affiliate => data[:affiliateUrl],
				:cover => data[:largeImageUrl],
			}.delete_if{|k,v| v.nil? || v.class == String && v.empty?}
		end

		def title(data)
			title = data[:title]
			title += " #{data[:subTitle]}" unless data[:subTitle].nil? || data[:subTitle].empty?
			title
		end

		def sales_date(data)
			date = data[:salesDate].match(/(?<year>[0-9]+)年((?<month>[0-9]+)月)?((?<day>[0-9]+)日)?(?<suffix>.*)/)
			return nil if date.nil? || date[:year].nil?
			sales_date = date[:year]
			sales_date += "-#{date[:month].nil? ? '01' : date[:month]}"
			sales_date += "-#{date[:day].nil? ? '01' : date[:day]}"
			# sales_date += "(#{date[:suffix]})" unless date[:suffix].empty?
			sales_date
		end
	end
end
