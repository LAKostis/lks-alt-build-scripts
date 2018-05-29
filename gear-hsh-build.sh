#!/bin/sh -efu
gear-hsh -- --packager="L.A. Kostis <lakostis@altlinux.org>" --mountpoints=/proc /opt/builds/tmp 2>&1|tee build.log.tmp && \
	mv build.log.tmp build.log

