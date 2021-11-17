#! /bin/bash
# SPDX-License-Identifier: Apache-2.0
#===============================
#
# make
#
# 2021/11/11 Kuninori Morimoto <kuninori.morimoto.gx@renesas.com>
#===============================
TOP=`readlink -f "$0" | xargs dirname | xargs dirname`
. ${TOP}/scripts/param.sh

[ x${FLAG_ADAS} != x ] && ADAS="-adas"
[ x${FLAG_MMP}  != x ] && MMP="-mmp"

[ x${NAME_BIN} != x ] && NAME_BIN="yocto-${VER}-${TARGET}${ADAS}${MMP}-${DATE}-bin"
[ x${NAME_SRC} != x ] && NAME_SRC="yocto-${VER}-${TARGET}${ADAS}${MMP}-${DATE}-src"
[ x${NAME_ENV} != x ] && NAME_ENV="yocto-${VER}-${TARGET}${ADAS}${MMP}-${DATE}-env"

[ x${NAME_BIN} != x -a -f ${NAME_BIN}.tar.bz2 ] && echo "${NAME_BIN}.tar.bz2 already exist" && exit 1
[ x${NAME_SRC} != x -a -f ${NAME_SRC}.tar.bz2 ] && echo "${NAME_SRC}.tar.bz2 already exist" && exit 1
[ x${NAME_ENV} != x -a -f ${NAME_ENV}.tar.bz2 ] && echo "${NAME_ENV}.tar.bz2 already exist" && exit 1

META_BSP=meta-rcar-gen3/docs/sample/conf/${TARGET}/poky-gcc/bsp
META_MMP=meta-rcar-gen3/docs/sample/conf/${TARGET}/poky-gcc/mmp

ARCH_MODE=patched # original  patched  configured

conf_path_check() {

	if [ ! -d  meta-renesas/${META_BSP} ]; then
		echo "no ${META_BSP} at renesas"
		exit
	fi

	grep -w "INHERIT" meta-renesas/${META_BSP}/local.conf > /dev/null
	if [ $? = 0 ]; then
		echo "unexpected: renesas local.conf has INHERIT!"
		exit
	fi

	grep -w "ARCHIVER_MODE" meta-renesas/${META_BSP}/local.conf > /dev/null
	if [ $? = 0 ]; then
		echo "unexpected: renesas local.conf has ARCHIVER_MODE!"
		exit
	fi
}

unpack_mmp() {
	COPY_SCRIPT="${TOP}/meta-renesas/meta-rcar-gen3/docs/sample/copyscript/copy_evaproprietary_softwares.sh"
	DIR=${TOP}/package/${VER}/unzip

	if [ ! -f ${COPY_SCRIPT} ]; then
		error "scripts to copy drivers for Gen3 not found."
		exit 1
	fi

	if [ ! -d ${TOP}/package/${VER}/unzip ]; then
		ZIP=`get_param "${VER}_M"`
		(
			mkdir -p ${DIR}
			cd       ${DIR}
			for zip in ${ZIP}
			do
				unzip -o ../${zip}
			done
		)
	fi

	(
		cd ${TOP}/meta-renesas/
		${COPY_SCRIPT} -d -f ${DIR}
	)
	[ x$? != x0 ] && exit

	cp ../meta-renesas/${META_MMP}/*.conf ./conf/
	cp ./conf/local-wayland.conf ./conf/local.conf
}

target_build() {
	(
		. poky/oe-init-build-env

		grep ${VER}${ADAS}${MMP}   ${TOP}/build/renesas-version 2>/dev/null
		[ $? != 0 ] && echo "removing previous build/tmp" && rm -fr build/tmp
		echo ${VER}${ADAS}${MMP} > ${TOP}/build/renesas-version

		IMAGE=minimal
		cp ../meta-renesas/${META_BSP}/*.conf ./conf/

		if [ x${FLAG_MMP} != x ]; then
			unpack_mmp
			IMAGE=weston
		fi

		if [ x${FLAG_ADAS} != x ]; then
			bitbake-layers add-layer ../meta-rcar/meta-rcar-gen3-adas
		fi

		if [ x${NAME_SRC} != x ]; then
			echo						>> ./conf/local.conf
			echo "# added by renesas-yocto-maker"		>> ./conf/local.conf
			echo "INHERIT += \"archiver\""			>> ./conf/local.conf
			echo "ARCHIVER_MODE[src] = \"$ARCH_MODE\""	>> ./conf/local.conf
		fi

		bitbake core-image-${IMAGE}
	)
	[ x$? != x0 ] && exit
}

run_option() {

	if [ x${NAME_BIN} != x ]; then
		echo create ${NAME_BIN}
		ln -s build/tmp/deploy/images/${TARGET} ${NAME_BIN}
		tar -jchf ${NAME_BIN}.tar.bz2 ${NAME_BIN}
		rm ${NAME_BIN}
	fi

	if [ x${NAME_SRC} != x ]; then
		echo create ${NAME_SRC}

		if [ x${ARCH_MODE} = xoriginal ]; then
			ln -s build/tmp/deploy/sources	${NAME_SRC}
		else
			mkdir ${NAME_SRC}
			SRC=`find build/tmp/deploy/sources/ | grep ${ARCH_MODE}`
			cp ${SRC} ${NAME_SRC}
		fi

		tar -jchf ${NAME_SRC}.tar.bz2 ${NAME_SRC}
		rm -fr ${NAME_SRC}
	fi

	if [ x${NAME_ENV} != x ]; then
		echo create ${NAME_ENV}
		mkdir -p ${NAME_ENV}/build
		ln -s ../../build/conf		${NAME_ENV}/build
		ln -s ../../build/downloads	${NAME_ENV}/build
		ln -s ../meta-openembedded	${NAME_ENV}
		ln -s ../meta-renesas		${NAME_ENV}
		if [ x${FLAG_ADAS} != x ]; then
			ln -s ../meta-rcar	${NAME_ENV}
		fi
		ln -s ../poky			${NAME_ENV}
		tar -jchf ${NAME_ENV}.tar.bz2	${NAME_ENV}
		rm -fr ${NAME_ENV}
	fi
}

conf_path_check
target_build
run_option