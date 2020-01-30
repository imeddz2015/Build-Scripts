#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Hiredis from sources.

HIREDIS_TAR=v0.14.0.tar.gz
HIREDIS_DIR=hiredis-0.14.0
PKG_NAME=hidredis

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

if ! ./build-expat.sh
then
    echo "Failed to build Expat"
    exit 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

echo
echo "********** Hiredis **********"
echo

if ! "$WGET" -O "$HIREDIS_TAR" --ca-certificate="$DIGICERT_ROOT" \
     "https://github.com/redis/hiredis/archive/$HIREDIS_TAR"
then
    echo "Failed to download Hiredis"
    exit 1
fi

rm -rf "$HIREDIS_DIR" &>/dev/null
gzip -d < "$HIREDIS_TAR" | tar xf -
cd "$HIREDIS_DIR"

cp ../patch/hiredis.patch .
patch -u -p0 < hiredis.patch
echo ""

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

echo "**********************"
echo "Building package"
echo "**********************"

	MAKE_FLAGS=()
	MAKE_FLAGS+=("-f" "Makefile")
	MAKE_FLAGS+=("-j" "$INSTX_JOBS")
	MAKE_FLAGS+=("PREFIX=$INSTX_PREFIX")
	MAKE_FLAGS+=("LIBDIR=$INSTX_LIBDIR")
	MAKE_FLAGS+=("PKGLIBDIR=${BUILD_PKGCONFIG[*]}")

    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
"$MAKE" "${MAKE_FLAGS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to build Hiredis"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

echo
echo "Unable to test Hiredis"
echo

# Need redis-server
#MAKE_FLAGS=("check" "V=1")
#if ! "$MAKE" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test Hidredis"
#    exit 1
#fi

#echo "Searching for errors hidden in log files"
#COUNT=$(find . -name '*.log' -exec grep -o 'runtime error:' {} \; | wc -l)
#if [[ "${COUNT}" -ne 0 ]];
#then
#    echo "Failed to test Hidredis"
#    exit 1
#fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
MAKE_FLAGS+=("PREFIX=$INSTX_PREFIX")
MAKE_FLAGS+=("LIBDIR=$INSTX_LIBDIR")
MAKE_FLAGS+=("PKGLIBDIR=${BUILD_PKGCONFIG[*]}")

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

    ARTIFACTS=("$HIREDIS_TAR" "$HIREDIS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-hidredis.sh 2>&1 | tee build-hidredis.log
    if [[ -e build-hidredis.log ]]; then
        rm -f build-hidredis.log
    fi
fi

exit 0
