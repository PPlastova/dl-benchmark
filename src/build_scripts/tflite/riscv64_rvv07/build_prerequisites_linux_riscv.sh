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
    --rebuild_tflite)
      REBUILD_TFLITE=YES
      shift # past argument
      shift # past value
      ;;
    --recompile_tflite)
      RECOMPILE_TFLITE=YES
      shift # past argument
      shift # past value
      ;;
    --rebuild_opencv)
      REBUILD_OPENCV=YES
      shift # past argument
      shift # past value
      ;;
    --rebuild_json)
      REBUILD_JSON=YES
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
    --rebuild_tflite - Rebuild tflite framework
    --rebuild_opencv - Rebuild opencv framework
    --rebuild_json - Rebuild json framework
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
    BUILD_DIR="${REPO_ROOT}/build_tflite_riscv_rvv07"
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

TFLITE_BRANCH="pplastova_tflite_riscv_rvvgemm_rvvdwconv"
if [ ! -d ${WORKDIR}/tensorflow_${TFLITE_BRANCH} ]
then
    git clone -b ${TFLITE_BRANCH} https://github.com/PPlastova/tensorflow.git ${WORKDIR}/tensorflow_${TFLITE_BRANCH}
    REBUILD_TFLITE=YES
fi

if [ -d ${BUILD_DIR}/tflite_riscv_build ]
then
    if [[ ! -z "${REBUILD_TFLITE}" ]]
    then
        rm -rf ${BUILD_DIR}/tflite_riscv_build/*
    fi
else
    mkdir ${BUILD_DIR}/tflite_riscv_build
    REBUILD_TFLITE=YES
fi

if [[ ! -z "${REBUILD_TFLITE}" ]]
then
    echo "Start building TFLite for RISCV..."
    cmake -S ${WORKDIR}/tensorflow_${TFLITE_BRANCH}/tensorflow/lite/ -B ${BUILD_DIR}/tflite_riscv_build \
        -D CMAKE_BUILD_TYPE=Release -D BUILD_SHARED_LIBS=ON \
        -D TFLITE_ENABLE_GPU=ON -D CMAKE_SYSTEM_NAME=Linux -D CMAKE_SYSTEM_PROCESSOR=riscv64 \
        -D CMAKE_C_COMPILER=${RISCV_C_COMPILER} -D CMAKE_CXX_COMPILER=${RISCV_CXX_COMPILER} \
        -D CMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
        -D CMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
        -D CMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
        -D CMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
        -D CMAKE_CXX_FLAGS_INIT="-march=rv64imafdcv0p7_zfh_xtheadc -mabi=lp64d -D__riscv_vector_071 -mrvv-vector-bits=128" \
        -D CMAKE_C_FLAGS_INIT="-march=rv64imafdcv0p7_zfh_xtheadc -mabi=lp64d -D__riscv_vector_071 -mrvv-vector-bits=128" \
        -D TFLITE_ENABLE_XNNPACK=ON -DXNNPACK_ENABLE_RISCV_VECTOR=ON -DTFLITE_ENABLE_GPU=OFF \
        -D XNNPACK_TARGET_PROCESSOR=riscv \
        -D XNNPACK_ENABLE_ARM_FP16_SCALAR=OFF \
        -D XNNPACK_ENABLE_ARM_BF16=OFF \
        -D XNNPACK_ENABLE_ARM_FP16_VECTOR=OFF \
        -D XNNPACK_ENABLE_ARM_DOTPROD=OFF \
        -D XNNPACK_ENABLE_ARM_I8MM=OFF \
        -D XNNPACK_BUILD_TESTS=OFF \
        -D XNNPACK_BUILD_BENCHMARKS=OFF \
        -D XNNPACK_DEBUG_LOGGING=ON \
        -D XNNPACK_ENABLE_CPUINFO=OFF \
        -D XNNPACK_DELEGATE_ENABLE_SUBGRAPH_RESHAPING=1

    cmake --build ${BUILD_DIR}/tflite_riscv_build --config Release --parallel $(nproc)

    mkdir ${BUILD_DIR}/tmp_tflite_riscv_build_libs
    find ${BUILD_DIR}/tflite_riscv_build -type f -name "*.so" -exec cp {} ${BUILD_DIR}/tmp_tflite_riscv_build_libs \;
    cp ${BUILD_DIR}/tmp_tflite_riscv_build_libs/* ${BUILD_DIR}/tflite_riscv_build
    rm -rf ${BUILD_DIR}/tmp_tflite_riscv_build_libs/
fi

if [[ ! -z "${RECOMPILE_TFLITE}" ]]
then
    cmake --build ${BUILD_DIR}/tflite_riscv_build --config Release --parallel $(nproc)

    mkdir ${BUILD_DIR}/tmp_tflite_riscv_build_libs
    find ${BUILD_DIR}/tflite_riscv_build -type f -name "*.so" -exec cp {} ${BUILD_DIR}/tmp_tflite_riscv_build_libs \;
    cp ${BUILD_DIR}/tmp_tflite_riscv_build_libs/* ${BUILD_DIR}/tflite_riscv_build
    rm -rf ${BUILD_DIR}/tmp_tflite_riscv_build_libs/
fi

if [ ! -d ${WORKDIR}/opencv ]
then
    git clone -b 4.x https://github.com/opencv/opencv.git ${WORKDIR}/opencv
fi

if [ -d ${BUILD_DIR}/opencv_riscv_build ]
then
    if [[ ! -z "${REBUILD_OPENCV}" ]]
    then
        rm -rf ${BUILD_DIR}/opencv_riscv_build/*
    fi
else
    mkdir ${BUILD_DIR}/opencv_riscv_build
    REBUILD_OPENCV=YES
fi

if [[ ! -z "${REBUILD_OPENCV}" ]]
then
    echo "Start building OpenCV for RISCV..."
    cmake -S ${WORKDIR}/opencv -B ${BUILD_DIR}/opencv_riscv_build -D CMAKE_BUILD_TYPE=Release \
        -D WITH_OPENCL=OFF \
        -D CMAKE_SYSTEM_NAME=Linux -D CMAKE_SYSTEM_PROCESSOR=riscv64 -D BUILD_SHARED_LIBS=OFF -D CMAKE_SYSROOT=${RISCV_SYSROOT} \
        -D CMAKE_C_COMPILER=${RISCV_C_COMPILER} -D CMAKE_CXX_COMPILER=${RISCV_CXX_COMPILER} \
        -D CMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
        -D CMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
        -D CMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
        -D CMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
        -D BUILD_TESTS=OFF -D BUILD_EXAMPLES=OFF -D BUILD_PERF_TESTS=OFF \
        -D BUILD_ZLIB=ON \
        -D CMAKE_CXX_FLAGS_INIT="-march=rv64imafdcv0p7_zfh_xtheadc -mabi=lp64d -D__riscv_vector_071 -mrvv-vector-bits=128" \
        -D CMAKE_C_FLAGS_INIT="-march=rv64imafdcv0p7_zfh_xtheadc -mabi=lp64d -D__riscv_vector_071 -mrvv-vector-bits=128"
    cd ${BUILD_DIR}/opencv_riscv_build
    make -j$(nproc)
fi

if [ ! -d ${WORKDIR}/json ]
then
    git clone https://github.com/nlohmann/json.git ${WORKDIR}/json
fi

if [ -d ${BUILD_DIR}/json_build ]
then
    if [[ ! -z "${REBUILD_JSON}" ]]
    then
        rm -rf ${BUILD_DIR}/json_build/*
    fi
else
    mkdir ${BUILD_DIR}/json_build
    REBUILD_JSON=YES
fi

if [[ ! -z "${REBUILD_JSON}" ]]
then
    echo "Start building JSON..."
    cmake -S ${WORKDIR}/json -B ${BUILD_DIR}/json_build -D JSON_BuildTests=OFF
    cmake --build ${BUILD_DIR}/json_build --config Release -- -j$(nproc)
fi