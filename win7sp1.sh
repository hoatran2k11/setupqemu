#!/data/data/com.termux/files/usr/bin/bash

echo "Choose language for questions:"
echo "1. Tiếng Việt"
echo "2. English"
read -p "Select language (1/2): " lang_choice

if [ "$lang_choice" == "1" ]; then
    LANG_RAM="Số GB RAM bạn muốn dùng cho máy ảo: "
    LANG_CPU="Số nhân CPU bạn muốn dùng cho máy ảo: "
    LANG_DISK="Dung lượng ổ cứng cho máy ảo (GB): "
    LANG_VIRTIO_NET_PROMPT="Bạn có muốn dùng card mạng VirtIO không (Y/N): "
    LANG_VIRTIO_NET_NOTE="Bạn sẽ phải tự chuẩn bị file .iso cài driver VirtIO, hãy đổi tên nó thành virtio.iso và đặt vào cùng thư mục với script này nhé!"
    LANG_NET_CARD_TYPE="Card mạng bạn muốn dùng (ví dụ: e1000, rtl8139): "
    LANG_VNC_PORT="Port VNC bạn muốn dùng: "
    LANG_ISO_PATH="Đường dẫn đến file ISO Windows (ví dụ: /sdcard/Downloads/win7.iso): "
    LANG_VM_NAME="Tên file ổ cứng ảo (ví dụ: win7_disk.qcow2): "
    LANG_INSTALL_QEMU_MSG="Đang cài đặt QEMU và các gói cần thiết..."
    LANG_CONFIG_VM_MSG="Đang cấu hình máy ảo..."
    LANG_START_VM_MSG="Khởi động máy ảo. Bạn có thể kết nối VNC đến địa chỉ IP của thiết bị Android của bạn với port đã chọn."
else
    LANG_RAM="Enter RAM for VM in GB: "
    LANG_CPU="Enter number of CPU cores for VM: "
    LANG_DISK="Enter virtual disk size in GB: "
    LANG_VIRTIO_NET_PROMPT="Do you want to use VirtIO network card (Y/N): "
    LANG_VIRTIO_NET_NOTE="You will need to provide the VirtIO driver .iso. Please rename it to virtio.iso and place it in the same directory as this script!"
    LANG_NET_CARD_TYPE="Enter desired network card type (e.g., e1000, rtl8139): "
    LANG_VNC_PORT="Enter VNC port to use: "
    LANG_ISO_PATH="Path to Windows ISO file (e.g., /sdcard/Downloads/win7.iso): "
    LANG_VM_NAME="Virtual disk filename (e.g., win7_disk.qcow2): "
    LANG_INSTALL_QEMU_MSG="Installing QEMU and necessary packages..."
    LANG_CONFIG_VM_MSG="Configuring virtual machine..."
    LANG_START_VM_MSG="Starting virtual machine. You can connect via VNC to your Android device's IP address with the chosen port."
fi

clear

echo "$LANG_INSTALL_QEMU_MSG"
termux-setup-storage
apt update -y
apt upgrade -y
pkg install -y x11-repo
pkg install -y qemu-system-x86_64 curl qemu-utils

clear

echo "$LANG_CONFIG_VM_MSG"

read -p "$LANG_RAM" VM_RAM_GB
read -p "$LANG_CPU" VM_CPU_CORES
read -p "$LANG_DISK" VM_DISK_GB
read -p "$LANG_VIRTIO_NET_PROMPT" USE_VIRTIO_NET
USE_VIRTIO_NET=$(echo "$USE_VIRTIO_NET" | tr '[:upper:]' '[:lower:]') # Chuyển về chữ thường

NET_ARGS=""
if [ "$USE_VIRTIO_NET" == "y" ]; then
    NET_ARGS="-netdev user,id=vnet0 -device virtio-net-pci,netdev=vnet0"
    echo "---"
    echo "$LANG_VIRTIO_NET_NOTE"
    echo "---"
    VIRTIO_ISO_DRIVE="-cdrom virtio.iso"
else
    read -p "$LANG_NET_CARD_TYPE" NET_CARD_TYPE
    NET_ARGS="-netdev user,id=vnet0 -device ${NET_CARD_TYPE},netdev=vnet0"
    VIRTIO_ISO_DRIVE=""
fi

read -p "$LANG_VNC_PORT" VNC_PORT
read -p "$LANG_ISO_PATH" WINDOWS_ISO_PATH
read -p "$LANG_VM_NAME" VM_DISK_FILE

VM_RAM_MB=$((VM_RAM_GB * 1024))

if [ ! -f "$VM_DISK_FILE" ]; then
    qemu-img create -f qcow2 "$VM_DISK_FILE" "${VM_DISK_GB}G"
else
    echo "File ổ cứng ảo '$VM_DISK_FILE' đã tồn tại, sẽ sử dụng file này."
fi

echo "---"
echo "$LANG_START_VM_MSG"
echo "Lệnh QEMU được tạo:"
echo "qemu-system-x86_64 -m ${VM_RAM_MB} -cpu host -smp ${VM_CPU_CORES} -hda ${VM_DISK_FILE} -cdrom ${WINDOWS_ISO_PATH} ${VIRTIO_ISO_DRIVE} ${NET_ARGS} -vnc :${VNC_PORT} -boot d"
echo "---"

qemu-system-x86_64 \
    -m "${VM_RAM_MB}" \
    -cpu host \
    -smp "${VM_CPU_CORES}" \
    -hda "${VM_DISK_FILE}" \
    -cdrom "${WINDOWS_ISO_PATH}" \
    ${VIRTIO_ISO_DRIVE} \
    ${NET_ARGS} \
    -vnc ":${VNC_PORT}" \
    -boot d
