# Resources Changelog

## Unreleased

## 0.12.0

### New/Changed Features

* Bump QEMU to 9.2.0

## 0.11.0

### New/Changed Features

* Enable hardware acceleration (KVM) on Linux

## 0.10.0

### New/Changed Features

* Bundle QEMU UEFI for x86-64
* Bump QEMU to 8.2.0

## 0.9.1

### Bugs Fixed:

* Disable `capstone`

## 0.9.0

### New/Changed Features

* Bump QEMU to 8.0.3

## 0.8.0

### New/Changed Features

* Bump QEMU to 8.0.2

## 0.7.0

### New/Changed Features

* Bundle Linaro UEFI for ARM64
* Bump QEMU to 7.2.0

## 0.6.0

### New/Changed Features

* Add support for ARM64 as a target architecture
* Strip binaries to save space

## 0.5.1

### Bugs Fixed:

* Bundling of Bhyve UEFI firmware

## 0.5.0

### New/Changed Features

* Bundle QEMU EFI firmware

## 0.4.0

### New/Changed Features:

* Bump QEMU to 6.2.0
* The CI script can now be used on Apple Silicon

## 0.3.1

### New/Changed Features:

* Statically link all non-system provided libraries on macOS

### Bugs Fixed:

* Missing QEMU dependency glib ([cross-platform-actions/action#5](https://github.com/cross-platform-actions/action/issues/5))

## 0.3.0

### New/Changed Features

* Removed all unused architectures. The only remaining one is x86_64
* Bundle missing firmware

## 0.2.0

### New/Changed Features

* Add support for the QEMU hypervisor
* Add support for Linux as the host
* Add support for the following target architectures:
    * aarch64
    * alpha
    * arm
    * hppa
    * i386
    * m68k
    * mips
    * mips64
    * mips64el
    * mipsel
    * ppc
    * ppc64
    * riscv32
    * riscv64
    * s390x
    * sparc
    * sparc64
    * x86_64

## 0.0.1

Initial release.
