#!/bin/sh -efu

 . gear-sh-functions

pkgs=
vers=
specfile=
hshopts='-q'
hshroot='/opt/builds/tmp'
hshrepo='/opt/builds/tmp/repo'
arepo_mode='lib'
pkgsdir='/ALT'
pkg_keep=

show_help() {
	cat <<EOF
Usage: $PROG [options] <pkgs...>

Options:

  -r, --release=RELEASE   version to build, default is taken from .gear .spec;
  --hsh-options=<OPTS>    hasher initroot options;
  --hsh-root=<PATH>       hasher initroot location;
  --hsh-repo=<PATH>       hasher result repo location;
  --arepo-mode=(lib|prog) arepo build mode;
  --pkgsdir=<PATH>        donor repo location;
  --keep                  keep existing pkg versions;
  -V, --version           print program version and exit;
  -h, --help              show this text and exit.

EOF
	exit
}

print_version() {
	cat <<EOF
$PROG version $PROG_VERSION
Written by Konstantin Lepikhov <lakostis@altlinux.org>

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
EOF
	exit
}

# packages without native conflicts
native_packages="^wine-vanilla$|^steam$"

TEMP=`getopt -n $PROG -o 'r:,o:h,V' -l 'release:,hsh-options:,hsh-root:,hsh-repo:,arepo-mode:,pkgsdir:,keep,help,version' -- "$@"` ||
	show_usage
eval set -- "$TEMP"

while :; do
	case "$1" in
		-r|--release) shift; vers="$1"
			;;
		-o|--hsh-options) shift; hshopts="$1"
			;;
		--hsh-root) shift; hshroot="$1"
			;;
		--hsh-repo) shift; hshrepo="$1"
			;;
		--arepo-mode) shift; arepo_mode="$1"
			;;
		--pkgsdir) shift; pkgsdir="$1"
			;;
		--keep) pkg_keep=1
			;;
		-h|--help) show_help
			;;
		-V|--version) print_version
			;;
		--) shift; break
			;;
	esac
	shift
done

case "$arepo_mode" in
	lib|prog)
		;;
	*) fatal 'Invalid arepo mode, should either prog or lib!'
		;;
esac

pkgs="${@:-}"
arepo="$hshrepo/x86_64-i586"
vers_orig=

[ -n "$pkgs" ] || show_usage

if [ -z "$vers" ]; then
	guess_specfile

	[ -s "$specfile" ] ||
		fatal 'No specfile found.'

	get_NVR_from_spec "$specfile"
	pkg_name="$spec_name"
	pkg_epoch="$spec_epoch"
	pkg_version="$spec_version"
	pkg_release="$spec_release"
	vers="$pkg_version-$pkg_release"
fi

i386 hsh "$hshopts" --init --target=i586 --apt-config=/home/lakostis/Documents/apt.conf.i586 "$hshroot"
hsh-install "$hshopts" "$hshroot" rpmrebuild-arepo && \
cp -a "$pkgsdir"/Sisyphus/files/list/arepo-x86_64-i586.list "$hshroot"/chroot/.in/
if [ -n "$pkgs" ]; then
	for pkg in $pkgs; do
		for arch in x86_64 i586; do
			if [ "$arch" == "x86_64" ]; then
				printf '%s' $pkg | egrep -qs "$native_packages" && continue
			fi
			if [ "$pkg" != "${pkg%%=*}" ]; then
				vers_orig="$vers"
				vers=${pkg##*=}
				pkg=${pkg%%=*}
			fi
			if [ -s "$hshroot"/repo/$arch/RPMS.hasher/$pkg-$vers.$arch.rpm ]; then
				cp -a "$hshroot"/repo/$arch/RPMS.hasher/$pkg-$vers.$arch.rpm "$hshroot"/chroot/.in/
			elif [ -n "$hshrepo" -a "${hshrepo##/repo}" != "$hshroot" ]; then
				[ -s "$hshrepo"/$arch/RPMS.hasher/$pkg-$vers.$arch.rpm ] && \
					cp -a "$hshrepo"/$arch/RPMS.hasher/$pkg-$vers.$arch.rpm "$hshroot"/chroot/.in/
			fi
		done
		[ -n "$vers_orig" ] && vers=$vers_orig
		vers_orig=
	done
fi
cat > "$hshroot"/chroot/.in/build.sh <<EOF
#!/bin/sh -eu
for i in *.i586.rpm; do
    export AREPO_MODE="$arepo_mode"
    export AREPO_PKGLIST=arepo-x86_64-i586.list
    export AREPO_ARCH=i586
    export AREPO_COMPAT="\$i"
    [ -s \$(basename "\$i" .i586.rpm).x86_64.rpm ] && export AREPO_NATIVE="\$(basename "\$i" .i586.rpm).x86_64.rpm" ||:
    rpmrebuild -np --include arepo.plug "\$i"
done
EOF
chmod +x "$hshroot"/chroot/.in/build.sh
hsh-run "$hshopts" "$hshroot" ./build.sh && echo 'Build completed, copying pkgs back...'
for pkg in $pkgs; do
        if [ "$pkg" != "${pkg%%=*}" ]; then
		vers_orig="$vers"
		vers=${pkg##*=}
                pkg=${pkg%%=*}
                printf 'Got pkg %s vers %s\n' $pkg $vers ||:
		if [ ! -n "$pkg_keep" ]; then
			set +f && \
			rm -f $arepo/RPMS.hasher/i586-$pkg* ||:
		fi
        fi
	cp -a "$hshroot"/chroot/usr/src/RPM/RPMS/i586/i586-$pkg-$vers.i586.rpm "$arepo"/RPMS.hasher/
	[ -n "$vers_orig" ] && vers=$vers_orig
	vers_orig=
done
echo -n 'Updating arepo repo...'
rm -rf "$arepo"/base && \
mkdir -p "$arepo"/base && \
genbasedir --bloat --topdir="$hshrepo" x86_64-i586 && echo 'Done!'
