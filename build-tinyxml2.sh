#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds TinyXML from sources.

TXML2_TAR=7.1.0.tar.gz
TXML2_DIR=tinyxml2-7.1.0
PKG_NAME=tinyxml

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT INT

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
echo "********** TinyXML2 **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$TXML2_TAR" --ca-certificate="$GITHUB_ROOT" \
     "https://github.com/leethomason/tinyxml2/archive/$TXML2_TAR"
then
    echo "Failed to download tinyxml2"
    exit 1
fi

rm -rf "$TXML2_DIR" &>/dev/null
gzip -d < "$TXML2_TAR" | tar xf -
cd "$TXML2_DIR"

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

MAKE_FLAGS=("-j" "$INSTX_JOBS")
MAKE_FLAGS+=("PKG_CONFIG_PATH=${BUILD_PKGCONFIG[*]}")
MAKE_FLAGS+=("CPPFLAGS=${BUILD_CPPFLAGS[*]}")
MAKE_FLAGS+=("CFLAGS=${BUILD_CFLAGS[*]}")
MAKE_FLAGS+=("CXXFLAGS=${BUILD_CXXFLAGS[*]}")
MAKE_FLAGS+=("LDFLAGS=${BUILD_LDFLAGS[*]}")
MAKE_FLAGS+=("LIBS=${BUILD_LIBS[*]}")

echo "**********************"
echo "Building package"
echo "**********************"

if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build tinyxml2"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("test")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
   echo "Failed to test tinyxml2"
   exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

# TODO... fix this simple copy
echo "Installing TinyXML2"
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S cp tinyxml2.h "$INSTX_PREFIX/include"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S cp libtinyxml2.a "$INSTX_LIBDIR"
    echo ""
else
    cp tinyxml2.h "$INSTX_PREFIX/include"
    cp libtinyxml2.a "$INSTX_LIBDIR"
    echo ""
fi

cd "$CURR_DIR" || exit 1

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PKG_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$TXML2_TAR" "$TXML2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-tinyxml2.sh 2>&1 | tee build-tinyxml2.log
    if [[ -e build-tinyxml2.log ]]; then
        rm -f build-tinyxml2.log
    fi
fi

exit 0
