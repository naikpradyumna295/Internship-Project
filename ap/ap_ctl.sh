#!/bin/sh

setup()
{
  bundle install
  update
}

start()
{
	bundle exec pumactl start
}

stop()
{
	bundle exec pumactl stop
}

update()
{
	bundle exec ruby ./misc/caching_openbd.rb -nocover
}

case "$1" in
	setup)
		setup
		;;
	start)
		start
		;;
	stop)
		stop
		;;
	update)
		update
		;;
	*)
		echo "usage> ap_ctl [setup|start|stop|update]"
		;;
esac
