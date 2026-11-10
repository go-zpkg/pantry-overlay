platforms = "linux"
provides = [
  "boot/Image",
]
versions = [
  {
    match = "/linux-\\d+\\.\\d+\\.\\d+\\.tar\\.xz/"
    strip = [
      "/linux-/",
      "/\\.tar\\.xz/",
    ]
    url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/"
  },
]

build {
  dependencies = {
    "elfutils.org" = "*"
    "github.com/westes/flex" = "*"
    "gnu.org/bc" = "*"
    "gnu.org/bison" = "*"
    "gnu.org/gawk" = "*"
    "openssl.org" = "^3"
  }
  env = {
    HOSTCFLAGS = "-Wno-implicit-function-declaration -Wno-implicit-int -Wno-int-conversion"
    "linux/aarch64" = {
      KERNEL_IMAGE = "Image"
      KERNEL_IMAGE_PATH = "arch/arm64/boot/Image"
    }
    "linux/x86-64" = {
      KERNEL_IMAGE = "bzImage"
      KERNEL_IMAGE_PATH = "arch/x86/boot/bzImage"
    }
  }
  script = [
    "make defconfig",
    {
      run = <<EOT
# RDMA, and the software transports that make it reachable without
# hardware. rdma-core is in the pantry now, and libibverbs opens
# /dev/infiniband/uverbs* — a device this kernel did not create, so the
# userspace half had nothing to talk to. RXE (soft-RoCE) and SIW
# (soft-iWARP) give a working RDMA stack over ordinary Ethernet, which
# is what makes UCX's --with-verbs path testable in a microVM on a
# laptop rather than only on a cluster.
#
# mlx5 is the HCA an actual cluster has, and only reachable in a guest
# once VFIO can hand the device through. VFIO earns its place the same
# way for GPUs. PCI_P2PDMA is GPUDirect: the NIC reading GPU memory
# without a bounce through the host.
#
# All =y, because MODULES is disabled below: a microVM kernel that
# needed a modules tree beside it would not be one artefact any more.
./scripts/config \
  --enable VIRTIO --enable VIRTIO_PCI --enable VIRTIO_MMIO \
  --enable VIRTIO_BLK --enable VIRTIO_NET --enable VIRTIO_CONSOLE \
  --enable FUSE_FS --enable VIRTIO_FS \
  --enable CGROUPS --enable BLK_CGROUP --enable CGROUP_SCHED \
  --enable CGROUP_PIDS --enable CGROUP_FREEZER --enable CGROUP_DEVICE \
  --enable MEMCG --enable NAMESPACES --enable USER_NS --enable PID_NS \
  --enable NET_NS --enable UTS_NS --enable IPC_NS \
  --enable OVERLAY_FS --enable SECCOMP --enable SECCOMP_FILTER \
  --enable TMPFS --enable TMPFS_POSIX_ACL --enable DEVTMPFS \
  --enable DEVTMPFS_MOUNT --enable BLK_DEV_INITRD --enable RD_GZIP \
  --enable INFINIBAND --enable INFINIBAND_USER_ACCESS \
  --enable INFINIBAND_ADDR_TRANS --enable RDMA_RXE --enable RDMA_SIW \
  --enable MLX5_CORE --enable MLX5_INFINIBAND \
  --enable VFIO --enable VFIO_PCI --enable VFIO_IOMMU_TYPE1 \
  --enable TRANSPARENT_HUGEPAGE --enable PCI_P2PDMA \
  --disable MODULES
make olddefconfig
EOT
    },
    "make --jobs {{ hw.concurrency }} CC=\"$ZBK_CC_FREESTANDING\" $KERNEL_IMAGE",
    "mkdir -p \"{{prefix}}/boot\" \"{{prefix}}/share/kernel\"",
    "cp \"$KERNEL_IMAGE_PATH\" \"{{prefix}}/boot/Image\"",
    "cp .config \"{{prefix}}/share/kernel/config\"",
  ]
}

distributable {
  strip-components = 1
  url = "https://cdn.kernel.org/pub/linux/kernel/v{{version.major}}.x/linux-{{version}}.tar.xz"
}

test {
  script = <<EOT
test -s {{prefix}}/boot/Image
grep -q "^CONFIG_VIRTIO_FS=y" {{prefix}}/share/kernel/config
grep -q "^CONFIG_OVERLAY_FS=y" {{prefix}}/share/kernel/config
grep -q "^CONFIG_USER_NS=y" {{prefix}}/share/kernel/config
grep -q "^CONFIG_INFINIBAND_USER_ACCESS=y" {{prefix}}/share/kernel/config
grep -q "^CONFIG_INFINIBAND_ADDR_TRANS=y" {{prefix}}/share/kernel/config
grep -q "^CONFIG_RDMA_RXE=y" {{prefix}}/share/kernel/config
grep -q "^CONFIG_VFIO_PCI=y" {{prefix}}/share/kernel/config
grep -q "^CONFIG_TRANSPARENT_HUGEPAGE=y" {{prefix}}/share/kernel/config
EOT
}
