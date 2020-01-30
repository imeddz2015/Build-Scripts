#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Gnulib from sources.

# Gnulib is distributed as source from GitHub. No packages
# are available for download. Also see
# https://www.linux.com/news/using-gnulib-improve-software-portability

GNULIB_DIR=gnulib
PKG_NAME=Gnulib

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

echo
echo "********** Gnulib **********"
echo

if ! git clone --depth=3 git://git.savannah.gnu.org/gnulib.git "$GNULIB_DIR"
then
    echo "Failed to clone Gnulib"
    exit 1
fi

cd "$GNULIB_DIR"

#cp ../patch/gnulib.patch .
#patch -u -p0 < gnulib.patch
#echo ""

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

echo "**********************"
echo "Building package"
echo "**********************"

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
    SHELL="$(command -v bash)" \
"$MAKE" "-j" "$INSTX_JOBS" "V=1"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to build Gnulib"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Gnulib"
    exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test Gnulib"
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

    ARTIFACTS=("$GNULIB_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-Gnulib.sh 2>&1 | tee build-gnulib.log
    if [[ -e build-gnulib.log ]]; then
        rm -f build-gnulib.log
    fi
fi

exit 0
