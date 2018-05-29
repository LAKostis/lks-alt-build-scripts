#!/bin/sh -efu
i386 gear-hsh -- --packager="L.A. Kostis <lakostis@altlinux.org>" --target=i586 --apt-config=/home/lakostis/Documents/apt.conf.i586 --mountpoints=/proc /opt/builds/tmp 2>&1|tee build.log.i586.tmp && \
	mv build.log.i586.tmp build.log.i586

