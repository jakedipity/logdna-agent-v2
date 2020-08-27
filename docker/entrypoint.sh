#!/bin/sh

case "$3" in
	Darwin*)	HOST_MACHINE=Mac;;
	Linux*)		HOST_MACHINE=Linux;;
	*)		HOST_MACHINE="Unknown:$3";;
esac

if [ "$HOST_MACHINE" = "Mac" ]; then
	/bin/sh -c "$5"
elif [ "$HOST_MACHINE" = "Linux" ]; then
	USER=$(id -nu "$1" 2>&1)
	GROUP=$(getent group "$2" | cut -d: -f1)

	if [ -z "$GROUP" ]; then
	    GROUP=logdna
	    groupadd -g "$2" logdna
	fi

	if case "$USER" in *"no such user") true ;; *) false ;; esac; then
	    USER=logdna
	    useradd -g "$GROUP" -u "$1" -m logdna
	fi

	chown -R "$USER":"$GROUP" "$4"
	runuser -u "$USER" -g "$GROUP" -- /bin/sh -c "$5"
else
	echo "Detected unknown operating system on host machine \"$HOST_MACHINE\""
	exit 1
fi

