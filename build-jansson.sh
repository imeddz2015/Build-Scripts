#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Jansson from sources.

JANSSON_VER=2.12
JANSSON_TAR=jansson-$JANSSON_VER.tar.gz
JANSSON_DIR=jansson-$JANSSON_VER
PKG_NAME=jansson

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
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

echo
echo "********** Jansson **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$JANSSON_TAR" --ca-certificate="$GITHUB_ROOT" \
     "https://github.com/akheron/jansson/archive/v$JANSSON_VER.tar.gz"
then
    echo "Failed to download Jansson"
    exit 1
fi

rm -rf "$JANSSON_DIR" &>/dev/null
gzip -d < "$JANSSON_TAR" | tar xf -
cd "$JANSSON_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/jansson.patch ]]; then
    cp ../patch/jansson.patch .
    patch -u -p0 < jansson.patch
    echo ""
fi

# No damn configure...
if [[ -n "$(command -v glibtoolize 2>/dev/null)" ]]; then
    if ! autoreconf -i; then
        echo "Failed to bootstrap Jansson"
        exit 1
    fi
elif [[ -n "$(command -v libtoolize 2>/dev/null)" ]]; then
    if ! autoreconf -i; then
        echo "Failed to bootstrap Jansson"
        exit 1
    fi
else
    echo "Failed to bootstrap Jansson"
    exit 1
fi

# Fix sys_lib_dlsearch_path_spec
cp -p ../fix-configure.sh .
./fix-configure.sh

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    --disable-assert \
    --with-libxml2 \
    # --enable-lib-only

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Jansson"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Jansson"
    exit 1
fi

# Fix flags in *.pc files
cp -p ../fix-pkgconfig.sh .
./fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "**********************"
    echo "Failed to test Jansson"
    echo "**********************"
    #exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "**********************"
    echo "Failed to test Jansson"
    echo "**********************"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR" || exit 1

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PKG_CACHE/$PKG_NAME"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$JANSSON_TAR" "$JANSSON_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-jansson.sh 2>&1 | tee build-jansson.log
    if [[ -e build-jansson.log ]]; then
        rm -f build-jansson.log
    fi
fi

exit 0