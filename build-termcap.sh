#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Termcap from sources.

TERMCAP_TAR=termcap-1.3.1.tar.gz
TERMCAP_DIR=termcap-1.3.1
PKG_NAME=termcap

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

if [[ -e "$INSTX_CACHE/$PKG_NAME" ]]; then
    # Already installed, return success
    echo ""
    echo "$PKG_NAME is already installed."
    exit 0
fi

# Get a sudo password as needed. The password should die when this
# subshell goes out of scope.
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

echo
echo "********** Termcap **********"
echo

if ! "$WGET" -O "$TERMCAP_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/termcap/$TERMCAP_TAR"
then
    echo "Failed to download Termcap"
    exit 1
fi

rm -rf "$TERMCAP_DIR" &>/dev/null
gzip -d < "$TERMCAP_TAR" | tar xf -
cd "$TERMCAP_DIR"

cp ../patch/termcap.patch .
patch -u -p0 < termcap.patch
echo ""

# Write package config file
rm -f 2>/dev/null termcap.pc
echo 'prefix='"$INSTX_PREFIX" >> termcap.pc
echo 'libdir=${prefix}/'"$(basename "$INSTX_LIBDIR")" >> termcap.pc
echo 'includedir=${prefix}/include' >> termcap.pc
echo '' >> termcap.pc
echo 'Name: Termcap' >> termcap.pc
echo 'Version: 1.3.1' >> termcap.pc
echo 'Description: Terminal capabilites library' >> termcap.pc
echo 'URL: https://www.gnu.org/software/termutils' >> termcap.pc
echo 'Libs: -L${libdir} -ltermcap' >> termcap.pc
echo 'Cflags: -I${includedir}' >> termcap.pc

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure \
    --prefix="$INSTX_PREFIX" \
    --enable-shared \
    --enable-install-termcap \
    --with-termcap="$INSTX_PREFIX/etc"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Termcap"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

ARFLAGS="cr"
MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! ARFLAGS="$ARFLAGS" "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Termcap"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Termcap"
    #exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test Termcap"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install" "libdir=$INSTX_LIBDIR")
if [[ -n "$SUDO_PASSWORD" ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$TERMCAP_TAR" "$TERMCAP_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-termcap.sh 2>&1 | tee build-termcap.log
    if [[ -e build-termcap.log ]]; then
        rm -f build-termcap.log
    fi
fi

exit 0
