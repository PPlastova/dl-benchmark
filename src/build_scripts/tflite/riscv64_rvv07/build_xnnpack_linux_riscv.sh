#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_ROOT=$(realpath "$SCRIPT_DIR/../../../..")

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--toolchain_path)
      TOOLCHAIN_PATH="$2"
      shift # past argument
      shift # past value
      ;;
    -w|--workdir)
      WORKDIR="$2"
      shift # past argument
      shift # past value
      ;;
    -b|--build_dir)
      BUILD_DIR="$2"
      shift # past argument
      shift # past value
      ;;
    --rebuild_xnnpack)
      REBUILD_XNNPACK=YES
      shift # past argument
      shift # past value
      ;;
    --recompile_xnnpack)
      RECOMPILE_XNNPACK=YES
      shift # past argument
      shift # past value
      ;;
    --pack_archive)
      PACK_ARCHIVE=YES
      shift # past argument
      shift # past value
      ;;
    -h|--help)
      PRINT_HELP=YES
      shift # past argument
      shift # past value
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters
if [[ ! -z "${PRINT_HELP}" ]] 
then
    echo "Supported arguments: 
    -t / --tolchain_path - path to RISCV gcc toolchain. If not specified, the toolchain will be downloaded to workdir
    -w / --workdir - working directory for downloading and building processes. Default: dl-benchmark/downloads
    -b / --build_dir - directory for builded packages. Default: dl-benchmark/build
    --rebuild_xnnpack - Rebuild xnnpack framework
    "
    exit 1
fi

if [[ -z "${WORKDIR}" ]] 
then
    WORKDIR="${REPO_ROOT}/downloads"
    if [[ ! -d ${WORKDIR} ]]
    then
        mkdir ${WORKDIR}
    fi
fi

echo "WORKDIR = ${WORKDIR}"

if [[ -z "${BUILD_DIR}" ]] 
then
    BUILD_DIR="${REPO_ROOT}/build_xnnpack_riscv_rvv07"
    if [[ ! -d ${BUILD_DIR} ]]
    then
        mkdir ${BUILD_DIR}
    fi
fi

echo "BUILD_DIR = ${BUILD_DIR}"

if [[ -z "${TOOLCHAIN_PATH}" ]] 
then
    if [ ! -d ${WORKDIR}/riscv ]
    then
        echo "Starting downloading xuantie-gnu-toolchain for ubuntu 20.04 version 2.8.1 ..."
        wget -O ${WORKDIR}/riscv_toolchain.tgz 'https://occ-oss-prod.oss-cn-hangzhou.aliyuncs.com/resource//1705395627867/Xuantie-900-gcc-linux-5.10.4-glibc-x86_64-V2.8.1-20240115.tar.gz'
        tar -xvzf ${WORKDIR}/riscv_toolchain.tgz -C ${WORKDIR}
        mv ${WORKDIR}/Xuantie-900-gcc-linux-5.10.4-glibc-x86_64-V2.8.1 ${WORKDIR}/riscv
    fi
    TOOLCHAIN_PATH=${WORKDIR}/riscv
fi

if [ ! -d ${TOOLCHAIN_PATH}/bin ] && [ ! -d ${TOOLCHAIN_PATH}/sysroot ] && \
      [ ! -f ${TOOLCHAIN_PATH}/bin/riscv64-unknown-linux-gnu-gcc ] && \
      [ ! -f ${TOOLCHAIN_PATH}/bin/riscv64-unknown-linux-gnu-g++ ]
then
    echo "Error: Not suitable toolchain in TOOLCHAIN_PATH. Toolchain must contain riscv64-unknown-linux-gnu-gcc and riscv64-unknown-linux-gnu-g++ compilers"
    exit 1
else
    echo "TOOLCHAIN_PATH = ${TOOLCHAIN_PATH}"
    RISCV_C_COMPILER=${TOOLCHAIN_PATH}/bin/riscv64-unknown-linux-gnu-gcc
    RISCV_CXX_COMPILER=${TOOLCHAIN_PATH}/bin/riscv64-unknown-linux-gnu-g++
    RISCV_SYSROOT=${TOOLCHAIN_PATH}/sysroot
fi

if [ ! -d ${WORKDIR}/xnnpack ]
then
    git clone -b pplastova_tflite_riscv https://github.com/PPlastova/XNNPACK.git ${WORKDIR}/xnnpack
fi

if [ -d ${BUILD_DIR}/xnnpack_riscv_build ]
then
    if [[ ! -z "${REBUILD_XNNPACK}" ]]
    then
        rm -rf ${BUILD_DIR}/xnnpack_riscv_build/*
    fi
else
    mkdir ${BUILD_DIR}/xnnpack_riscv_build
    REBUILD_XNNPACK=YES
fi

if [[ ! -z "${REBUILD_XNNPACK}" ]]
then
    echo "Start building XNNPACK for RISCV..."
    cmake -S ${WORKDIR}/xnnpack -B ${BUILD_DIR}/xnnpack_riscv_build \
        -D CMAKE_BUILD_TYPE=Release \
        -D CMAKE_SYSTEM_NAME=Linux -D CMAKE_SYSTEM_PROCESSOR=riscv64 \
        -D CMAKE_C_COMPILER=${RISCV_C_COMPILER} -D CMAKE_CXX_COMPILER=${RISCV_CXX_COMPILER} \
        -D CMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
        -D CMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
        -D CMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
        -D CMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
        -D CMAKE_CXX_FLAGS_INIT="-march=rv64imafdcv0p7_zfh_xtheadc -mabi=lp64d -D__riscv_vector_071 -mrvv-vector-bits=128" \
        -D CMAKE_C_FLAGS_INIT="-march=rv64imafdcv0p7_zfh_xtheadc -mabi=lp64d -D__riscv_vector_071 -mrvv-vector-bits=128" \
        -D XNNPACK_ENABLE_RISCV_VECTOR=ON \
        -D XNNPACK_TARGET_PROCESSOR=riscv \
        -D XNNPACK_ENABLE_ARM_FP16_SCALAR=OFF \
        -D XNNPACK_ENABLE_ARM_BF16=OFF \
        -D XNNPACK_ENABLE_ARM_FP16_VECTOR=OFF \
        -D XNNPACK_ENABLE_ARM_DOTPROD=OFF \
        -D XNNPACK_ENABLE_ARM_I8MM=OFF \
        -D XNNPACK_BUILD_TESTS=ON \
        -D XNNPACK_BUILD_BENCHMARKS=ON \
        -D XNNPACK_ENABLE_CPUINFO=OFF \
        -D XNNPACK_DEBUG_LOGGING=OFF

    cmake --build ${BUILD_DIR}/xnnpack_riscv_build --config Release --parallel $(nproc)
fi

if [[ ! -z "${RECOMPILE_XNNPACK}" ]]
then
    cmake --build ${BUILD_DIR}/xnnpack_riscv_build --config Release --parallel $(nproc)
fi

if [[ ! -z "${PACK_ARCHIVE}" ]]
then
    cd ${BUILD_DIR}/
    tar -cvzf ${BUILD_DIR}/xnnpack_riscv_build.tgz -C ${BUILD_DIR}/xnnpack_riscv_build/ .
fi