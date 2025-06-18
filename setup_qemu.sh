#!/bin/bash

# Hàm kiểm tra và cài đặt QEMU
install_qemu() {
    echo "Kiểm tra và cài đặt QEMU..."
    if ! command -v qemu-system-x86_64 &> /dev/null; then
        echo "QEMU chưa được cài đặt. Đang tiến hành cài đặt..."
        if [ -f /etc/debian_version ]; then
            sudo apt update && sudo apt install -y qemu-system-x86 qemu-utils
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y qemu-kvm qemu-img
        else
            echo "Hệ điều hành không được hỗ trợ để cài đặt tự động QEMU. Vui lòng cài đặt QEMU thủ công."
            exit 1
        fi
        echo "QEMU đã được cài đặt thành công."
    else
        echo "QEMU đã được cài đặt."
    fi
}

# Hàm tải file bằng wget
download_file() {
    local url="$1"
    local output_file="$2"
    if [ -n "$url" ]; then
        if [[ "$url" =~ ^https?:// ]]; then # Kiểm tra nếu là URL
            echo "Đang tải $url về $output_file..."
            wget -O "$output_file" "$url"
            if [ $? -ne 0 ]; then
                echo "Lỗi khi tải file từ $url. Vui lòng kiểm tra lại URL hoặc kết nối mạng."
                exit 1
            fi
            echo "Đã tải xong $output_file."
        else
            echo "Đường dẫn '$url' không phải là URL. Sẽ sử dụng như đường dẫn cục bộ."
        fi
    fi
}


install_qemu

echo "---"
echo "Thiết lập máy ảo QEMU"
echo "---"

# Lấy thông tin từ người dùng
read -p "Số nhân CPU bạn muốn dùng cho máy ảo là: " CPU_CORES
read -p "Số GB RAM bạn muốn dùng cho máy ảo là: " RAM_GB
read -p "Dung lượng ổ cứng bạn muốn dùng cho máy ảo là (M = MiB, G = GiB): " DISK_SIZE
read -p "Bạn có muốn bật VNC không ? [Y/N]: " ENABLE_VNC
read -p "Bạn có muốn cho máy ảo dùng card mạng virtio không (yêu cầu có link iso driver virtio nếu là windows): [Y/N]: " ENABLE_VIRTIO_NET

VIRTIO_DRIVER_ISO_PATH=""
if [[ "$ENABLE_VIRTIO_NET" =~ ^[Yy]$ ]]; then
    read -p "Nhập đường dẫn **URL** hoặc **cục bộ** đến file ISO driver virtio (nhấn Enter nếu không có hoặc dùng Linux): " VIRTIO_DRIVER_ISO_INPUT
    if [ -n "$VIRTIO_DRIVER_ISO_INPUT" ]; then
        VIRTIO_DRIVER_ISO_PATH="virtio_drivers.iso" # Tên file tải về/sử dụng
        download_file "$VIRTIO_DRIVER_ISO_INPUT" "$VIRTIO_DRIVER_ISO_PATH"
    fi
fi

OS_INSTALL_ISO_PATH=""
read -p "Nhập đường dẫn **URL** hoặc **cục bộ** đến file ISO cài đặt hệ điều hành (nhấn Enter nếu không có): " OS_INSTALL_ISO_INPUT
if [ -n "$OS_INSTALL_ISO_INPUT" ]; then
    OS_INSTALL_ISO_PATH="os_install.iso" # Tên file tải về/sử dụng
    download_file "$OS_INSTALL_ISO_INPUT" "$OS_INSTALL_ISO_PATH"
fi

read -p "Đặt tên cho máy ảo (sẽ dùng để đặt tên file .sh): " VM_NAME

VM_NAME_LOWER=$(echo "$VM_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
START_SCRIPT_NAME="${VM_NAME_LOWER}_startvm.sh"
DISK_IMAGE_NAME="${VM_NAME_LOWER}.qcow2"

# Tạo ảnh đĩa nếu chưa có
if [ ! -f "$DISK_IMAGE_NAME" ]; then
    echo "Tạo ảnh đĩa $DISK_IMAGE_NAME với dung lượng $DISK_SIZE..."
    qemu-img create -f qcow2 "$DISK_IMAGE_NAME" "$DISK_SIZE"
    if [ $? -ne 0 ]; then
        echo "Lỗi khi tạo ảnh đĩa. Vui lòng kiểm tra lại dung lượng hoặc quyền."
        exit 1
    fi
    echo "Ảnh đĩa đã được tạo thành công."
else
    echo "Ảnh đĩa $DISK_IMAGE_NAME đã tồn tại. Bỏ qua việc tạo mới."
fi

# Xây dựng lệnh QEMU
QEMU_CMD="qemu-system-x86_64"
QEMU_CMD+=" -enable-kvm" # Bật KVM để tăng hiệu suất (nếu có)
QEMU_CMD+=" -smp cores=$CPU_CORES"
QEMU_CMD+=" -m ${RAM_GB}G"
QEMU_CMD+=" -hda $DISK_IMAGE_NAME"
QEMU_CMD+=" -usb -device usb-tablet" # Thêm thiết bị USB tablet để chuột hoạt động tốt hơn
QEMU_CMD+=" -cpu host" # Sử dụng CPU của host để tăng hiệu suất

# Gắn ISO cài đặt OS nếu có
if [ -n "$OS_INSTALL_ISO_PATH" ]; then
    QEMU_CMD+=" -cdrom $OS_INSTALL_ISO_PATH"
    echo "ISO cài đặt hệ điều hành sẽ được gắn vào máy ảo."
fi

# Cấu hình VNC
if [[ "$ENABLE_VNC" =~ ^[Yy]$ ]]; then
    QEMU_CMD+=" -vnc :0" # Mặc định cổng VNC là 5900
    echo "VNC sẽ được bật trên cổng :0 (thường là 5900)."
fi

# Cấu hình card mạng VirtIO
if [[ "$ENABLE_VIRTIO_NET" =~ ^[Yy]$ ]]; then
    QEMU_CMD+=" -netdev user,id=vnet0 -device virtio-net-pci,netdev=vnet0"
    echo "Card mạng VirtIO sẽ được sử dụng."
    if [ -n "$VIRTIO_DRIVER_ISO_PATH" ]; then
        QEMU_CMD+=" -drive file=$VIRTIO_DRIVER_ISO_PATH,media=cdrom" # Gắn driver VirtIO như một CD-ROM
        echo "ISO driver VirtIO sẽ được gắn vào máy ảo."
    fi
else
    QEMU_CMD+=" -netdev user,id=vnet0 -device e1000,netdev=vnet0" # Mặc định sử dụng card mạng e1000
    echo "Card mạng e1000 sẽ được sử dụng."
fi

# Tạo file script khởi động máy ảo
echo "#!/bin/bash" > "$START_SCRIPT_NAME"
echo "" >> "$START_SCRIPT_NAME"
echo "echo \"Khởi động máy ảo $VM_NAME...\"" >> "$START_SCRIPT_NAME"
echo "$QEMU_CMD" >> "$START_SCRIPT_NAME"
echo "" >> "$START_SCRIPT_NAME"
echo "echo \"Máy ảo $VM_NAME đã dừng.\"" >> "$START_SCRIPT_NAME"

chmod +x "$START_SCRIPT_NAME"

echo "---"
echo "Thiết lập hoàn tất!"
echo "File khởi động máy ảo đã được tạo: ./${START_SCRIPT_NAME}"
echo "Để khởi động máy ảo, chạy lệnh: ./${START_SCRIPT_NAME}"
echo "---"
