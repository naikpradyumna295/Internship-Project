require 'digest'
require 'json'
require_relative '../modules/selfdb'
require_relative '../modules/openbd'
require_relative '../modules/rakuten_books'
require_relative '../secret'

$DB = SelfDB.setup(DB_NAME)
RaktenBooksAPI.setup(RAKUTEN_APP_ID)

def test(notes)
	puts notes, '-' * notes.length
	$DB.transaction :rollback => :always, :savepoint => true do
		yield
	end
	puts "\n"
end

test 'test session' do
	temp_user = SelfDB::User.temp_add
	puts "Add temp user: #{temp_user}"

	session_id = SelfDB::Session.login temp_user[:name], temp_user[:pw]
	puts "Login session id: #{session_id}"

	puts "Get session: #{SelfDB::Session.get session_id}"
	puts "Check session: #{SelfDB::Session.check session_id}"

	puts "User register: #{SelfDB::User.register session_id, 'test name' , 'test pasword'}"

	puts "Delete session: #{SelfDB::Session.delete session_id}"
	puts "Check session: #{SelfDB::Session.check session_id}"
rescue => e
	puts e.message
end

test 'test user' do
	user_name = '*** user ***'
	user_password = '*** password ***'

	SelfDB::User.add user_name, user_password
	puts "Add user:", SelfDB::Users.all
	puts "Check user: #{SelfDB::User.check user_name}"

	session_id = SelfDB::Session.login user_name, user_password
	puts "Login:", SelfDB::Sessions.all
	
	user = SelfDB::User.new session_id, user_password
	user.name = '@@@ change name @@@'
	puts "Change name: #{SelfDB::User.get(session_id)}"
	user.password = '@@@ change password @@@'
	puts "Change password: #{SelfDB::User.get(session_id)}"
	user.remove
	puts "Remove user:", SelfDB::Users.all
rescue => e
	puts e.message
end

test 'test book' do
	user_name = 'airis'
	user_password = '*** password ***'
	isbn = 9784829990124
	isbn2 = 9784065274125

	SelfDB::User.add user_name, user_password
	sid = SelfDB::Session.login user_name, user_password
	uid = SelfDB::User.get(sid)[:uid]
	puts "sid: #{sid}, uid: #{uid}"

	def show(uid, isbn, isbn2)
		target = [isbn, isbn2]
		puts "Terget ISBN: #{target}"
		puts "UserBooks:", SelfDB::UserBooks.where(:uid => uid, :isbn => target).all
		puts "BookData:", SelfDB::BookData.where(:isbn => target).all
	end
	show uid, isbn, isbn2
	
	SelfDB::Book.register(sid, RaktenBooksAPI.get({:isbn => isbn})[0])
	SelfDB::Book.register(sid, OpenBD.get(isbn2.to_s)[0])
	show uid, isbn, isbn2

	SelfDB::Book.update(sid, {:isbn => isbn, :購入予定 => false})
	base_table = SelfDB::User.books(sid)
	puts "User books: #{base_table.count}"

	puts "Update book:", base_table.where(Sequel[:書籍情報][:isbn] => isbn).all
	puts "Delete book: #{SelfDB::Book.delete(sid, isbn)}"
	puts "Update book:", base_table.where(Sequel[:書籍情報][:isbn] => isbn).all

	SelfDB::Session.clear
	show uid, isbn, isbn2

	puts "Remove user: #{SelfDB::User.remove user_name}"
	puts "User book count: #{SelfDB::UserBooks.where(:uid => uid).count}"
	puts "Delete book: #{SelfDB::BookData[isbn].delete}"
	show uid, isbn, isbn2
rescue => e
	puts e.message
end
