#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds iConv from sources.

# iConvert and GetText are unique among packages. They have circular
# dependencies on one another. We have to build iConv, then GetText,
# and iConv again. Also see https://www.gnu.org/software/libiconv/.
# The script that builds iConvert and GetText in accordance to specs
# is build-iconv-gettext.sh. You should use build-iconv-gettext.sh
# instead of build-iconv.sh directly

ICONV_TAR=libiconv-1.16.tar.gz
ICONV_DIR=libiconv-1.16
PKG_NAME=iconv

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
echo "********** iConv **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$ICONV_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/pub/gnu/libiconv/$ICONV_TAR"
then
    echo "Failed to download iConv"
    exit 1
fi

rm -rf "$ICONV_DIR" &>/dev/null
gzip -d < "$ICONV_TAR" | tar xf -
cd "$ICONV_DIR" || exit 1

cp ../patch/iconv.patch .
patch -u -p0 < iconv.patch
echo ""

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

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
    --enable-shared

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure iConv"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build iConv"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

# build-iconv-gettext has a circular dependency.
# The first build of iConv does not need 'make check'.
if [[ "${INSTX_DISABLE_ICONV_TEST:-0}" -ne 1 ]]
then
    echo "**********************"
    echo "Testing package"
    echo "**********************"

    MAKE_FLAGS=("check" "V=1")
    if ! "${MAKE}" "${MAKE_FLAGS[@]}"
    then
        echo "Failed to test iConv"
        exit 1
    fi

    echo "Searching for errors hidden in log files"
    COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
    if [[ "${COUNT}" -ne 0 ]]
    then
        echo "Failed to test iConv"
        exit 1
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
if true; then

    ARTIFACTS=("$ICONV_TAR" "$ICONV_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-iconv.sh 2>&1 | tee build-iconv.log
    if [[ -e build-iconv.log ]]; then
        rm -f build-iconv.log
    fi
fi

exit 0
