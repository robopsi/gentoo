# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=5

export CBUILD=${CBUILD:-${CHOST}}
export CTARGET=${CTARGET:-${CHOST}}
if [[ ${CTARGET} == ${CHOST} ]] ; then
	if [[ ${CATEGORY} == cross-* ]] ; then
		export CTARGET=${CATEGORY#cross-}
	fi
fi

WANT_AUTOMAKE="1.15"

inherit autotools flag-o-matic eutils

DESCRIPTION="Free Win64 runtime and import library definitions"
HOMEPAGE="http://mingw-w64.sourceforge.net/"
SRC_URI="mirror://sourceforge/mingw-w64/mingw-w64/mingw-w64-release/mingw-w64-v${PV}.tar.bz2"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="headers-only idl libraries tools"
RESTRICT="strip"

S="${WORKDIR}/mingw-w64-v${PV}"

is_crosscompile() {
	[[ ${CHOST} != ${CTARGET} ]]
}
just_headers() {
	use headers-only && [[ ${CHOST} != ${CTARGET} ]]
}
crt_with() {
	just_headers && echo --without-$1 || echo --with-$1
}
crt_use_enable() {
	just_headers && echo --without-$2 || use_enable "$@"
}
crt_use_with() {
	just_headers && echo --without-$2 || use_with "$@"
}

pkg_setup() {
	if [[ ${CBUILD} == ${CHOST} ]] && [[ ${CHOST} == ${CTARGET} ]] ; then
		die "Invalid configuration"
	fi
}

src_prepare() {
	epatch "${FILESDIR}/${P}-winpthreads.patch"
	epatch "${FILESDIR}/${P}-build.patch"
	eautoreconf
}

src_configure() {
	CHOST=${CTARGET} strip-unsupported-flags

	if ! just_headers; then
		mkdir "${WORKDIR}/headers"
		pushd "${WORKDIR}/headers" > /dev/null
		CHOST=${CTARGET} "${S}/configure" \
			--prefix="${T}/tmproot" \
			--with-headers \
			--without-crt \
			|| die
		popd > /dev/null
		append-cppflags "-I${T}/tmproot/include"
	fi

	local extra_conf=()

	case ${CTARGET} in
	x86_64*) extra_conf+=( --disable-lib32 --enable-lib64 ) ;;
	i?86*) extra_conf+=( --enable-lib32 --disable-lib64 ) ;;
	*) die "Unsupported ${CTARGET}" ;;
	esac

	CHOST=${CTARGET} econf \
		--prefix=/usr/${CTARGET} \
		--includedir=/usr/${CTARGET}/usr/include \
		--with-headers \
		--enable-sdk \
		$(crt_with crt) \
		$(crt_use_enable idl) \
		$(crt_use_with libraries libraries winpthreads,libmangle) \
		$(crt_use_with tools) \
		"${extra_conf[@]}"
}

src_compile() {
	if ! just_headers; then
		emake -C "${WORKDIR}/headers" install
	fi
	default
}

src_install() {
	default

	if is_crosscompile ; then
		# gcc is configured to look at specific hard-coded paths for mingw #419601
		dosym usr /usr/${CTARGET}/mingw
		dosym usr /usr/${CTARGET}/${CTARGET}
		dosym usr/include /usr/${CTARGET}/sys-include
	fi

	env -uRESTRICT CHOST=${CTARGET} prepallstrip
	rm -rf "${ED}/usr/share"
}
