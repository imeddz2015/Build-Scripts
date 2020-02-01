#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Emacs and its dependencies from sources.

EMACS_TAR=emacs-26.2.tar.gz
EMACS_DIR=emacs-26.2

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR"
}
trap finish EXIT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=4}"

###############################################################################

# Get the environment as needed. We can't export it because it includes arrays.
if ! source ./setup-environ.sh
then
    echo "Failed to set environment"
    exit 1
fi

# The password should die when this subshell goes out of scope
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./setup-password.sh
fi

###############################################################################

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    exit 1
fi

###############################################################################

if ! ./build-bzip.sh
then
    echo "Failed to build Bzip2"
    exit 1
fi

###############################################################################

if false; then

if ! ./build-ncurses.sh
then
    echo "Failed to build Ncurses"
    exit 1
fi

fi

###############################################################################

echo
echo "********** Emacs **********"
echo

if ! "$WGET" -O "$EMACS_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/emacs/$EMACS_TAR"
then
    echo "Failed to download Emacs"
    exit 1
fi

rm -rf "$EMACS_DIR" &>/dev/null
gzip -d < "$EMACS_TAR" | tar xf -
cd "$EMACS_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

CONFIG_OPTS=('--with-xml2' '--without-x' '--without-sound' '--without-xpm'
    '--without-jpeg' '--without-tiff' '--without-gif' '--without-png'
    '--without-rsvg' '--without-imagemagick' '--without-xft' '--without-libotf'
    '--without-m17n-flt' '--without-xaw3d' '--without-toolkit-scroll-bars'
    '--without-gpm' '--without-dbus' '--without-gconf' '--without-gsettings'
    '--without-makeinfo' '--without-compress-install' '--with-gnutls=no')

if [[ -e "/usr/include/selinux/context.h" ]] ||
   [[ -e "/usr/local/include/selinux/context.h" ]]; then
    CONFIG_OPTS+=('--without-selinux')
fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure \
    --host="$AUTOCONF_HOST" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure emacs"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
   echo "Failed to test Emacs"
   exit 1
fi

#echo "**********************"
#echo "Testing package"
#echo "**********************"

#MAKE_FLAGS=("check" "V=1")
#if ! "$MAKE" "${MAKE_FLAGS[@]}"
#then
#   echo "Failed to test Emacs"
#   exit 1
#fi

#echo "Searching for errors hidden in log files"
#COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
#if [[ "${COUNT}" -ne 0 ]];
#then
#    echo "Failed to test Emacs"
#    exit 1
#fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$EMACS_TAR" "$EMACS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-emacs.sh 2>&1 | tee build-emacs.log
    if [[ -e build-emacs.log ]]; then
        rm -f build-emacs.log
    fi
fi

exit 0
