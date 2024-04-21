# TensorFlow Lite build for Linux RISC-V platform

1. Build prerequisites for TensorFlow Lite launcher (CPP API):
 
   ```bash
   cd dl-benchmark/src/build_scripts/tflite/riscv64_rvv07
   ./build_prerequisites_linux_riscv.sh
   ```

1. Build TensorFlow Lite launcher (CPP API):

   ```bash
   cd dl-benchmark/src/build_scripts/tflite/riscv64_rvv07
   ./build_cpp_tflite_launcher_linux_riscv.sh
   ```

1. Prepare archive to be sent to RISC-V board:

   ```bash
   cd dl-benchmark/src/build_scripts/tflite/riscv64_rvv07
   ./pack_send_archive.sh
   ```

1. Move resulting `dl-benchmark/build/riscv64_rvv07_send_archive.tgz` to RISC-V board and unpack

   ```bash
   scp dl-benchmark/build/riscv64_rvv07_send_archive.tgz {YOUR BOARD IP AND PATH}
   mkdir builded_launcher_rvv07 && tar -xvzf riscv64_rvv07_send_archive.tgz -C builded_launcher_rvv07
   ```

1. Set `LD_LIBRARY_PATH` to builded packages:

   ```bash
   export LD_LIBRARY_PATH=builded_launcher_rvv07/tflite_riscv_build:builded_launcher_rvv07/opencv_riscv_build/lib:$LD_LIBRARY_PATH
   ```

1. Download model to test:

   ```bash
   wget https://storage.googleapis.com/download.tensorflow.org/models/mobilenet_v1_2018_08_02/mobilenet_v1_1.0_224.tgz
   mkdir mobilenet_v1_1.0_224 && tar -xvzf mobilenet_v1_1.0_224.tgz -C mobilenet_v1_1.0_224 && rm mobilenet_v1_1.0_224.tgz
   ```

1. Run TensorFlow Lite launcher (CPP API):

   ```bash
   ./builded_launcher_rvv07/cpp_tflite_launcher_riscv_build/bin/tflite_benchmark -m mobilenet_v1_1.0_224/mobilenet_v1_1.0_224.tflite
   ```