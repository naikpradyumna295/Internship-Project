require "puma/daemon"
require "fileutils"

AppDir = File.expand_path('..', __dir__)

['tmp', 'tmp/pids', 'log'].each do |path|
	mk_path = File.join(AppDir, path)
	FileUtils.mkdir_p(mk_path) unless Dir.exist?(mk_path)
end

directory AppDir
environment 'production'

# port 9302 # Listening 0.0.0.0
bind 'tcp://localhost:9302'
# bind "unix:///#{AppDir}/tmp/puma.sock" # Listening UNIX domain socket
silence_single_worker_warning
preload_app!
workers 2
threads 8, 16
daemonize true

pidfile "#{AppDir}/tmp/pids/puma.pid"
state_path "#{AppDir}/tmp/pids/puma.state"
stdout_redirect "#{AppDir}/log/app.log", "#{AppDir}/log/error.log"#, true

activate_control_app
