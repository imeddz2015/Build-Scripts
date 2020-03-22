#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Unistring from sources.

UNISTR_TAR=libunistring-0.9.10.tar.gz
UNISTR_DIR=libunistring-0.9.10
PKG_NAME=unistring

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR"
}
trap finish EXIT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=2}"

###############################################################################

# Get the environment as needed. We can't export it because it includes arrays.
if ! source ./setup-environ.sh
then
    echo "Failed to set environment"
    exit 1
fi

if [[ -e "$INSTX_PKG_CACHE/$PKG_NAME" ]]; then
    # Already installed, return success
    echo ""
    echo "$PKG_NAME is already installed."
    exit 0
fi

# The password should die when this subshell goes out of scope
if [[ "$SUDO_PASSWORD_SET" != "yes" ]]; then
    if ! source ./setup-password.sh
    then
        echo "Failed to process password"
        exit 1
    fi
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

echo
echo "********** Unistring **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$UNISTR_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/libunistring/$UNISTR_TAR"
then
    echo "Failed to download Unistring"
    exit 1
fi

rm -rf "$UNISTR_DIR" &>/dev/null
gzip -d < "$UNISTR_TAR" | tar xf -
cd "$UNISTR_DIR"

cp ../patch/unistring.patch .
patch -u -p0 < unistring.patch
echo ""

# Fix sys_lib_dlsearch_path_spec
cp -p ../fix-configure.sh .
./fix-configure.sh

# https://bugs.launchpad.net/ubuntu/+source/binutils/+bug/1340250
if [[ -n "$SH_NO_AS_NEEDED" ]]; then
    BUILD_LIBS[${#BUILD_LIBS[@]}]="$SH_NO_AS_NEEDED"
fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    --enable-shared

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Unistring"
    exit 1
fi

echo "************************"
echo "Building package"
echo "************************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Unistring"
    exit 1
fi

# Fix flags in *.pc files
cp -p ../fix-pkgconfig.sh .
./fix-pkgconfig.sh

echo "************************"
echo "Testing package"
echo "************************"

# Unistring fails one self test on older systems, like Fedora 1
# and Ubuntu 4. Allow the failure but print the result.
MAKE_FLAGS=("check" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "************************"
    echo "Failed to test Unistring"
    echo "************************"
    # exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "************************"
    echo "Failed to test Unistring"
    echo "************************"
    exit 1
fi

echo "************************"
echo "Installing package"
echo "************************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PKG_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$UNISTR_TAR" "$UNISTR_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-unistring.sh 2>&1 | tee build-unistring.log
    if [[ -e build-unistring.log ]]; then
        rm -f build-unistring.log
    fi
fi

exit 0
