# Reminder: Zephyr recommended dependecies are: git cmake ninja-build gperf ccache dfu-util device-tree-compiler wget python3-pip python3-setuptools python3-tk python3-wheel xz-utils file make gcc gcc-multilib software-properties-common -y

CMAKE_VERSION_NUMBER=$(cmake --version | grep "[0-9]*\.[0-9]*\.[0-9]*" | cut -d ' ' -f 3)
CMAKE_VERSION_MAJOR_NUMBER=$(echo $CMAKE_VERSION_NUMBER | cut -d '.' -f 1)
CMAKE_VERSION_MINOR_NUMBER=$(echo $CMAKE_VERSION_NUMBER | cut -d '.' -f 2)
CMAKE_VERSION_PATCH_NUMBER=$(echo $CMAKE_VERSION_NUMBER | cut -d '.' -f 3)

if ! (( $CMAKE_VERSION_MAJOR_NUMBER > 3 || \
    $CMAKE_VERSION_MAJOR_NUMBER == 3 && $CMAKE_VERSION_MINOR_NUMBER > 13 || \
    $CMAKE_VERSION_MAJOR_NUMBER == 3 && $CMAKE_VERSION_MINOR_NUMBER == 13 && $CMAKE_VERSION_PATCH_NUMBER >= 1 )); then
    echo "Error: installed CMake version must be equal or greater than 3.13.1."
    echo "Your current version is $CMAKE_VERSION_NUMBER."
    echo "Please if not installed follow the instructions: https://docs.zephyrproject.org/latest/getting_started/index.html"
    exit 1
fi

export PATH=~/.local/bin:"$PATH"
export ZEPHYR_VERSION="0.17.0"
export ARCH=$(uname -m)

# Install west
pip3 install --user -U west --break-system-packages

pushd $FW_TARGETDIR >/dev/null

    west init zephyrproject -m https://github.com/tsnlab/zephyr.git --mr ar4-mk3-rpi4b
    pushd zephyrproject >/dev/null
        west update
        west zephyr-export
    popd >/dev/null

    pip3 install -r zephyrproject/zephyr/scripts/requirements.txt --ignore-installed --break-system-packages

    if [ "$ARCH" = "aarch64" ]; then
        export SDK_VERSION=zephyr-sdk-${ZEPHYR_VERSION}_linux-aarch64.tar.xz
    else
        export SDK_VERSION=zephyr-sdk-${ZEPHYR_VERSION}_linux-x86_64.tar.xz
    fi

    wget https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_VERSION}/$SDK_VERSION
    tar -xvf $SDK_VERSION
    mv zephyr-sdk-${ZEPHYR_VERSION} zephyr-sdk
    pushd zephyr-sdk >/dev/null
        ./setup.sh -h -c
        sudo cp sysroots/x86_64-pokysdk-linux/usr/share/openocd/contrib/60-openocd.rules /etc/udev/rules.d
        sudo udevadm control --reload
    popd >/dev/null

    rm -rf $SDK_VERSION

    export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
    export ZEPHYR_SDK_INSTALL_DIR=$FW_TARGETDIR/zephyr-sdk

    # Import repos
    vcs import --retry 50 --input $PREFIX/config/$RTOS/generic/board.repos

    # ignore broken packages
    touch mcu_ws/ros2/rcl_logging/rcl_logging_spdlog/COLCON_IGNORE
    touch mcu_ws/ros2/rcl/COLCON_IGNORE
    touch mcu_ws/ros2/rosidl/rosidl_typesupport_introspection_cpp/COLCON_IGNORE
    touch mcu_ws/ros2/rcpputils/COLCON_IGNORE
    touch mcu_ws/ros2/ros2_tracing/test_tracetools/COLCON_IGNORE
    touch mcu_ws/uros/rcl/rcl_yaml_param_parser/COLCON_IGNORE
    touch mcu_ws/uros/rclc/rclc_examples/COLCON_IGNORE
    touch mcu_ws/ros2/ros2_tracing/lttngpy/COLCON_IGNORE

    pushd mcu_ws/uros/rcutils > /dev/null
        git apply $PREFIX/config/$RTOS/rcutils_update.patch
    popd >/dev/null

    # Upgrade sphinx
    pip install --force-reinstall Sphinx==4.2.0 --break-system-packages

popd >/dev/null
