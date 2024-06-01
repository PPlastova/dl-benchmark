#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_ROOT=$(realpath "$SCRIPT_DIR/../../../..")
git submodule update --init --recursive

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -b|--build_dir)
      BUILD_DIR="$2"
      shift # past argument
      shift # past value
      ;;
    --rebuild_cpp_launcher)
      REBUILD_CPP_LAUNCHER=YES
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
    -b / --build_dir - directory for builded packages. Default: dl-benchmark/build_tflite_riscv_rvv07
    --rebuild_cpp_launcher - Rebuild cpp tflite launcher
    "
    exit 1
fi

if [[ -z "${BUILD_DIR}" ]] 
then
    BUILD_DIR="${REPO_ROOT}/build_tflite_riscv_rvv07"
    if [[ ! -d ${BUILD_DIR} ]]
    then
        mkdir ${BUILD_DIR}
    fi
fi

echo "BUILD_DIR = ${BUILD_DIR}"

if [ ! -d ${BUILD_DIR}/tflite_riscv_build ]
then
    echo "Builded TFLite not exist in ${BUILD_DIR}. Build it using build_prerequisites_linux_riscv.sh"
    exit 1
else
    TFLITE_RISCV_BUILD=${BUILD_DIR}/tflite_riscv_build
    echo "TFLITE_RISCV_BUILD_DIR = ${TFLITE_RISCV_BUILD}"
fi

if [ ! -d ${BUILD_DIR}/opencv_riscv_build ]
then
    echo "Builded OpenCV not exist in ${BUILD_DIR}. Build it using build_prerequisites_linux_riscv.sh"
    exit 1
else
    OPENCV_RISCV_BUILD=${BUILD_DIR}/opencv_riscv_build
    echo "OPENCV_RISCV_BUILD_DIR = ${OPENCV_RISCV_BUILD}"
fi

if [ ! -d ${BUILD_DIR}/json_build ]
then
    echo "Builded JSON not exist in ${BUILD_DIR}. Build it using build_prerequisites_linux_riscv.sh"
    exit 1
else
    JSON_BUILD=${BUILD_DIR}/json_build
    echo "JSON_BUILD_DIR = ${JSON_BUILD}"
fi

if [ ! -d ${BUILD_DIR}/cpp_tflite_launcher_riscv_build ]
then
    echo "Builded dl-bench CPP TFlite launcher not exist in ${BUILD_DIR}. Build it using build_cpp_tflite_launcher_linux_riscv.sh"
    exit 1
else
    CPP_TFLITE_LAUNCHER_RISCV_BUILD=${BUILD_DIR}/cpp_tflite_launcher_riscv_build
    echo "CPP_TFLITE_LAUNCHER_RISCV_BUILD_DIR = ${CPP_TFLITE_LAUNCHER_RISCV_BUILD}"
fi

rm -rf ${BUILD_DIR}/riscv64_rvv07_send_archive/*
cp -r ${CPP_TFLITE_LAUNCHER_RISCV_BUILD} ${BUILD_DIR}/riscv64_rvv07_send_archive
cp -r ${TFLITE_RISCV_BUILD} ${BUILD_DIR}/riscv64_rvv07_send_archive
cp -r ${OPENCV_RISCV_BUILD} ${BUILD_DIR}/riscv64_rvv07_send_archive
tar -cvzf ${BUILD_DIR}/riscv64_rvv07_send_archive.tgz -C ${BUILD_DIR}/riscv64_rvv07_send_archive .