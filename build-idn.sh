#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds IDN from sources.

IDN_TAR=libidn-1.35.tar.gz
IDN_DIR=libidn-1.35
PKG_NAME=libidn

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

if ! ./build-iconv-gettext.sh
then
    echo "Failed to build iConv and GetText"
    exit 1
fi

###############################################################################

if ! ./build-unistr.sh
then
    echo "Failed to build Unistring"
    exit 1
fi

###############################################################################

echo
echo "********** IDN **********"
echo

if ! "$WGET" -O "$IDN_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/libidn/$IDN_TAR"
then
    echo "Failed to download IDN"
    exit 1
fi

rm -rf "$IDN_DIR" &>/dev/null
gzip -d < "$IDN_TAR" | tar xf -
cd "$IDN_DIR"

# https://bugs.launchpad.net/ubuntu/+source/binutils/+bug/1340250
if [[ -n "$SH_NO_AS_NEEDED" ]]; then
    BUILD_LIBS+=("$SH_NO_AS_NEEDED")
fi

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
    --libdir="$INSTX_LIBDIR" \
    --enable-shared \
    --disable-rpath \
    --disable-doc \
    --with-libiconv-prefix="$INSTX_PREFIX" \
    --with-libunistring-prefix="$INSTX_PREFIX"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure IDN"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build IDN"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

# Clang static links, GCC dynamic links. LIBASAB may be empty.
if [[ -n "$INSTX_ASAN" ]]
then
    # Determine the libasan.so that will be used.
    LIBASAB=$(ldd lib/.libs/libidn.so | grep -E 'libasan.so.*' | awk '{print $3}')
    echo "Using Asan library: $LIBASAB"
fi

# See if we need to LD_PRELOAD.
if [[ -n "$LIBASAB" ]]
then
    MAKE_FLAGS=("check" "V=1")
    if ! LD_PRELOAD="$LIBASAB" "$MAKE" "${MAKE_FLAGS[@]}"
    then
        echo "Failed to test IDN"
        exit 1
    fi
else
    MAKE_FLAGS=("check" "V=1")
    if ! "$MAKE" "${MAKE_FLAGS[@]}"
    then
        echo "Failed to test IDN"
        exit 1
    fi
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test IDN"
    exit 1
fi

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

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$IDN_TAR" "$IDN_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-idn.sh 2>&1 | tee build-idn.log
    if [[ -e build-idn.log ]]; then
        rm -f build-idn.log
    fi
fi

exit 0
