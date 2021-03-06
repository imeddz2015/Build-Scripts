#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds PCRE from sources.

PCRE2_TAR=pcre2-10.34.tar.gz
PCRE2_DIR=pcre2-10.34
PKG_NAME=pcre2

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

if ! ./build-bzip.sh
then
    echo "Failed to build Bzip2"
    exit 1
fi

###############################################################################

echo
echo "********** PCRE2 **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$PCRE2_TAR" --ca-certificate="$IDENTRUST_ROOT" \
     "https://ftp.pcre.org/pub/pcre/$PCRE2_TAR"
then
    echo "Failed to download PCRE2"
    exit 1
fi

rm -rf "$PCRE2_DIR" &>/dev/null
gzip -d < "$PCRE2_TAR" | tar xf -
cd "$PCRE2_DIR"

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG[*]}" \
    CPPFLAGS="${INSTX_CPPFLAGS[*]}" \
    CFLAGS="${INSTX_CFLAGS[*]}" \
    CXXFLAGS="${INSTX_CXXFLAGS[*]}" \
    LDFLAGS="${INSTX_LDFLAGS[*]}" \
    LIBS="${INSTX_LIBS[*]}" \
./configure \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    --enable-shared \
    --enable-pcre2-8 \
    --enable-pcre2-16 \
    --enable-pcre2-32

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure PCRE2"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build PCRE2"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

# PCRE2 fails one self test on older systems, like Fedora 1
# and Ubuntu 4. Allow the failure but print the result.
if [[ "$IS_LINUX" -ne 0 ]]; then
    MAKE_FLAGS=("check" "V=1")
    if ! "${MAKE}" "${MAKE_FLAGS[@]}"
    then
        echo "**********************"
        echo "Failed to test pcre2"
        echo "**********************"

        RETAIN_ARTIFACTS=true
        bash ../collect-logs.sh

        # exit 1
    fi
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S "${MAKE}" "${MAKE_FLAGS[@]}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR" || exit 1

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PKG_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
RETAIN_ARTIFACTS="${RETAIN_ARTIFACTS:-false}"
if [[ "${RETAIN_ARTIFACTS}" != "true" ]]; then

    ARTIFACTS=("$PCRE2_TAR" "$PCRE2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-pcre2.sh 2>&1 | tee build-pcre.log
    if [[ -e build-pcre2.log ]]; then
        rm -f build-pcre2.log
    fi
fi

exit 0
