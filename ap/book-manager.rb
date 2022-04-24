require 'uri'
require 'net/http'
require 'rack/protection'
require 'sinatra'
require 'sinatra/reloader'
require 'logger'
require 'sequel'
require_relative 'modules/selfdb'
require_relative 'modules/openbd'
require_relative 'modules/rakuten_books'
require_relative 'secret'

SelfDB.setup DB_NAME
RaktenBooksAPI.setup RAKUTEN_APP_ID, affiliate_id: RAKUTEN_AFFILIATE_ID

use Rack::Session::Cookie, secret: RACK_SESSION_SECRET, max_age: 3600*24*7
use Rack::Protection::AuthenticityToken
use Rack::Protection::ContentSecurityPolicy
use Rack::Protection::CookieTossing
use Rack::Protection::EscapedParams
use Rack::Protection::FormToken
use Rack::Protection::ReferrerPolicy
use Rack::Protection::RemoteReferrer
use Rack::Protection::StrictTransport
use Rack::Protection, permitted_origins: ["https://app.mrz-net.org"]

logger = Logger.new 'log/sinatra.log'

before do
	logger.debug "#{env['HTTP_X_FORWARDED_FOR']} #{env['REQUEST_METHOD']} #{env['REQUEST_URI']} #{session.inspect}"

	request.script_name = '/book-manager/api'
end

helpers do
	def csrf_token; Rack::Protection::AuthenticityToken.token(env['rack.session']); end
end

# 
# root
# 

get '/welcome' do
	logged_in = SelfDB::Session.check(session.id)
	user_type = !logged_in ? SelfDB::UserType::None : SelfDB::User.get(session.id)[:type]

	content_type :json
	JSON.dump({:loggedIn => logged_in, :_csrf => csrf_token, :userType => user_type})
end

post '/login' do
	SelfDB::Session.login params[:id], params[:pw], session.id
	user_type = SelfDB::User.get(session.id)[:type]

	content_type :json
	JSON.dump({:succeed => true, :_csrf => csrf_token, :userType => user_type})
rescue => e
	content_type :json
	JSON.dump({:succeed => false, :error => e.message})
end

delete '/logout' do
	result = SelfDB::Session.delete(session.id)

	content_type :json
	JSON.dump({:succeed => result == 1})
rescue => e
	content_type :json
	JSON.dump({:succeed => false})
end

get '/demo' do
	temp_user = SelfDB::User.temp_add
	logger.info "Add temp user: #{temp_user[:name]}, #{temp_user[:pw]}"

	SelfDB::Session.login temp_user[:name], temp_user[:pw], session.id

	content_type :json
	JSON.dump({:succeed => true, :_csrf => csrf_token, :userType => temp_user[:type]})
rescue => e
	content_type :json
	JSON.dump({:succeed => false, :error => e.message})
end

#
# user
#

patch '/user/register' do
	user = SelfDB::User.register session.id, params[:name], params[:pw]
	logger.info "Register user: #{user.name}, #{user.password}"

	content_type :json
	JSON.dump({:succeed => true})
rescue => e
	content_type :json
	JSON.dump({:succeed => false, :error => e.message})
end

patch '/user/name' do
	user = SelfDB::User.new session.id, params[:now]
	user.name = params[:new]
	logger.info "Change name: #{params[:new]}"

	content_type :json
	JSON.dump({:succeed => true})
rescue => e
	content_type :json
	JSON.dump({:succeed => false, :error => e.message})
end

patch '/user/password' do
	user = SelfDB::User.new session.id, params[:now]
	user.password = params[:new]
	logger.info "Change password: #{params[:new]}"

	content_type :json
	JSON.dump({:succeed => true})
rescue => e
	content_type :json
	JSON.dump({:succeed => false, :error => e.message})
end

#
# list
#

get '/list/unread' do
	content_type :json
	JSON.dump SelfDB.to_json SelfDB::User.books(session.id)
					.where(Sequel.lit('既読 != 1'))
					.where(Sequel.lit('所有 > 0'))
					.order(:発売日, :書籍名)
rescue => e
	content_type :json
	JSON.dump({:error => e.message})
end

get '/list/to-buy' do
	content_type :json
	JSON.dump SelfDB.to_json SelfDB::User.books(session.id)
					.where(Sequel.lit('既読 = 0'))
					.where(Sequel.lit('所有 = 0'))
					.where(:購入予定 => true)
					.where(Sequel.lit('発売日 <= CURRENT_DATE'))
					.order(Sequel.desc(:発売日), :書籍名)
rescue => e
	content_type :json
	JSON.dump({:error => e.message})
end

get '/list/to-buy/unpublished' do
	content_type :json
	JSON.dump SelfDB.to_json SelfDB::User.books(session.id)
					.where(Sequel.lit('既読 = 0'))
					.where(Sequel.lit('所有 = 0'))
					.where(:購入予定 => true)
					.where(Sequel.lit('発売日 > CURRENT_DATE'))
					.order(Sequel.asc(:発売日), :書籍名)
rescue => e
	content_type :json
	JSON.dump({:error => e.message})
end

get '/list/hold' do
	content_type :json
	JSON.dump SelfDB.to_json SelfDB::User.books(session.id)
					.where(Sequel.lit('所有 = 0'))
					.where(:購入予定 => false)
					.order(Sequel.desc(:発売日), :書籍名)
rescue => e
	content_type :json
	JSON.dump({:error => e.message})
end

#
# search
#

get '/search' do
	table = SelfDB::User.books(session.id)

	if params.has_key?(:isbn)
		table = table.where(Sequel[:書籍情報][:isbn] => params[:isbn])
	elsif params.has_key?(:title)
		table = table.where(Sequel.ilike(:書籍名, "%#{table.escape_like(params[:title])}%"))
	end

	if params.has_key?(:author)
		table = table.where(Sequel.|(
			Sequel.ilike(:著者, "%#{table.escape_like(params[:author])}%"),
			Sequel.ilike(:著者（読み）, "%#{table.escape_like(params[:author])}%"),
		))
	end

	if params.has_key?(:tag)
		table = table.where(Sequel.|(
			Sequel.ilike(Sequel[:書籍情報][:タグ], "%#{table.escape_like(params[:tag])}%"),
			Sequel.ilike(Sequel[:ユーザー拡張情報][:タグ], "%#{table.escape_like(params[:tag])}%"),
		))
	end

	books = SelfDB.to_json(table)
	books = OpenBD.get(params[:isbn]) if books.empty? && params.has_key?(:isbn)

	if books.empty? && params.has_key?(:isbn) || params.has_key?(:title) || params.has_key?(:author) || params.has_key?(:tag)
		RaktenBooksAPI.get(params).each do |book|
			books.append(book) if books.find{|v| v[:isbn] == book[:isbn]}.nil?
		end
	end

	# caching book image
	if File.writable?(CACHE_DIR)
		books.map {|book| 
			next unless book.has_key?(:cover)
			uri = URI.parse(book[:cover])
			ext = File.extname(uri.path)
			next unless ext == '.jpg' || ext == '.jpeg'
			cover_name = File.join(CACHE_DIR, "#{book[:isbn]}.jpg")
			next if File.exist?(cover_name)
			Thread.new(uri, cover_name) do |u, n|
				data = Net::HTTP.get(u)
				soi, app0, length, id = data[..11].unpack('S! S! S! A5')
				next unless soi == 0xD8FF
				next unless app0 == 0xE0FF
				next unless id == 'JFIF'
				puts "caching: #{n}"
				File.write(n, data)
			end
		}.each {|th| th.join unless th.nil?}
	end

	content_type :json
	JSON.dump(books.sort!{|a, b| b[:発売日] <=> a[:発売日]})
rescue => e
	content_type :json
	JSON.dump({:error => e.message})
end

#
# book
#

put '/book/register' do
	SelfDB::Book.register(session.id, params)

	content_type :json
	JSON.dump({:secceed => true})
rescue => e
	content_type :json
	JSON.dump({:secceed => false, :error => e.message})
end

patch '/book/:isbn' do
	result = SelfDB::Book.update(session.id, params)

	content_type :json
	JSON.dump({:secceed => !result.nil?})
rescue => e
	content_type :json
	JSON.dump({:secceed => false, :error => e.message})
end

delete '/book/:isbn' do
	result = SelfDB::Book.delete(session.id, params[:isbn])

	content_type :json
	JSON.dump({:secceed => result == 1})
rescue => e
	content_type :json
	JSON.dump({:succeed => false})
end
