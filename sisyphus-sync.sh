#!/bin/sh -efu

SRC=rsync.altlinux.org::ALTLinux/Sisyphus/
DIR=/ALT/Sisyphus

if [ -d "$DIR" ]; then
	rsync -avy --delete-after --exclude=aarch64 --exclude=armh "$SRC" "$DIR"/
else
	echo "Directory $DIR is not accessible, exiting..."
fi

