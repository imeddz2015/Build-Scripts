#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds GetText from sources.

# iConvert and GetText are unique among packages. They have circular
# dependencies on one another. We have to build iConv, then GetText,
# and iConv again. Also see https://www.gnu.org/software/libiconv/.
# The script that builds iConvert and GetText in accordance to specs
# is build-iconv-gettext.sh. You should use build-iconv-gettext.sh
# instead of build-gettext.sh directly

GETTEXT_TAR=gettext-0.20.2.tar.gz
GETTEXT_DIR=gettext-0.20.2
PKG_NAME=gettext

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

if ! ./build-ncurses.sh
then
    echo "Failed to build Ncurses"
    exit 1
fi

###############################################################################

echo
echo "********** GetText **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$GETTEXT_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/pub/gnu/gettext/$GETTEXT_TAR"
then
    echo "Failed to download GetText"
    exit 1
fi

rm -rf "$GETTEXT_DIR" &>/dev/null
gzip -d < "$GETTEXT_TAR" | tar xf -
cd "$GETTEXT_DIR" || exit 1

if false; then
cp -p gettext-runtime/gnulib-lib/xalloc-oversized.h \
	gettext-runtime/gnulib-lib/xalloc-oversized.h.orig
cp -p libtextstyle/lib/xalloc-oversized.h \
	libtextstyle/lib/xalloc-oversized.h.orig
cp -p gettext-tools/libgettextpo/xalloc-oversized.h \
	gettext-tools/libgettextpo/xalloc-oversized.h.orig
cp -p gettext-tools/gnulib-lib/xalloc-oversized.h \
	gettext-tools/gnulib-lib/xalloc-oversized.h.orig

cp -p gettext-runtime/gnulib-lib/xalloc.h \
	gettext-runtime/gnulib-lib/xalloc.h.orig
cp -p libtextstyle/lib/xalloc.h \
	libtextstyle/lib/xalloc.h.orig
cp -p gnulib-local/lib/xalloc.h \
	gnulib-local/lib/xalloc.h.orig
cp -p gettext-tools/libgettextpo/xalloc.h \
	gettext-tools/libgettextpo/xalloc.h.orig
cp -p gettext-tools/gnulib-lib/xalloc.h \
	gettext-tools/gnulib-lib/xalloc.h.orig

cp -p gettext-tools/libgrep/cdefs.h \
	gettext-tools/libgrep/cdefs.h.orig
cp -p gettext-tools/src/Makefile.in \
	gettext-tools/src/Makefile.in.orig
cp -p gettext-tools/gnulib-tests/Makefile.in \
	gettext-tools/gnulib-tests/Makefile.in.orig
cp -p gettext-tools/gnulib-tests/test-canonicalize-lgpl.c \
	gettext-tools/gnulib-tests/test-canonicalize-lgpl.c.orig
fi

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/gettext.patch ]]; then
    patch -u -p0 < ../patch/gettext.patch
    echo ""
fi

if false; then
# Clear the current patch
echo -n "" > ../patch/gettext.patch

diff -u gettext-runtime/gnulib-lib/xalloc-oversized.h.orig \
	gettext-runtime/gnulib-lib/xalloc-oversized.h >> ../patch/gettext.patch
diff -u libtextstyle/lib/xalloc-oversized.h.orig \
	libtextstyle/lib/xalloc-oversized.h >> ../patch/gettext.patch
diff -u gettext-tools/libgettextpo/xalloc-oversized.h.orig \
	gettext-tools/libgettextpo/xalloc-oversized.h >> ../patch/gettext.patch
diff -u gettext-tools/gnulib-lib/xalloc-oversized.h.orig \
	gettext-tools/gnulib-lib/xalloc-oversized.h >> ../patch/gettext.patch

diff -u gettext-runtime/gnulib-lib/xalloc.h.orig \
	gettext-runtime/gnulib-lib/xalloc.h >> ../patch/gettext.patch
diff -u libtextstyle/lib/xalloc.h.orig \
	libtextstyle/lib/xalloc.h >> ../patch/gettext.patch
diff -u gnulib-local/lib/xalloc.h.orig \
	gnulib-local/lib/xalloc.h >> ../patch/gettext.patch
diff -u gettext-tools/libgettextpo/xalloc.h.orig \
	gettext-tools/libgettextpo/xalloc.h >> ../patch/gettext.patch
diff -u gettext-tools/gnulib-lib/xalloc.h.orig \
	gettext-tools/gnulib-lib/xalloc.h >> ../patch/gettext.patch

diff -u gettext-tools/libgrep/cdefs.h.orig \
	gettext-tools/libgrep/cdefs.h >> ../patch/gettext.patch
diff -u gettext-tools/src/Makefile.in.orig \
	gettext-tools/src/Makefile.in >> ../patch/gettext.patch
diff -u gettext-tools/gnulib-tests/Makefile.in.orig \
	gettext-tools/gnulib-tests/Makefile.in >> ../patch/gettext.patch
diff -u gettext-tools/gnulib-tests/test-canonicalize-lgpl.c.orig \
	gettext-tools/gnulib-tests/test-canonicalize-lgpl.c >> ../patch/gettext.patch
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

if [[ -e "$INSTX_PREFIX/bin/sed" ]]; then
    export SED="$INSTX_PREFIX/bin/sed"
fi

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
    --enable-static \
    --enable-shared \
    --with-pic \
    --with-included-gettext \
    --with-included-libxml \
    --with-included-libunistring \
    --with-libiconv-prefix="$INSTX_PREFIX" \
    --with-libncurses-prefix="$INSTX_PREFIX"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure GetText"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build GetText"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

# Gnulib fails one self test on older systems, like Fedora 1
# and Ubuntu 4. Allow the failure but print the result.
MAKE_FLAGS=("check")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "**********************"
    echo "Failed to test GetText"
    echo "**********************"

    # Solaris and some friends fails lang-gawk
    # Darwin fails copy-acl-2.sh
    # https://lists.gnu.org/archive/html/bug-gawk/2018-01/msg00026.html
    if [[ "$IS_DARWIN" -eq 0 && "$SOLARIS" -eq 0 ]]; then
        exit 1
    fi
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S rm -rf "$INSTX_PREFIX/share/doc/gettext"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    rm -rf "$INSTX_PREFIX/share/doc/gettext"
fi

cd "$CURR_DIR" || exit 1

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PKG_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if false; then

    ARTIFACTS=("$GETTEXT_TAR" "$GETTEXT_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-gettext.sh 2>&1 | tee build-gettext.log
    if [[ -e build-gettext.log ]]; then
        rm -f build-gettext.log
    fi
fi

exit 0
