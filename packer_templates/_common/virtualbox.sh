#!/bin/sh -eux

# set a default HOME_DIR environment variable if not set
HOME_DIR="${HOME_DIR:-/home/vagrant}"

case "$PACKER_BUILDER_TYPE" in
  virtualbox-iso|virtualbox-ovf)
    VER="`cat $HOME_DIR/.vbox_version`"
    ISO="VBoxGuestAdditions_$VER.iso"

    # mount the ISO to /tmp/vbox
    mkdir -p /tmp/vbox || {
        echo "could not create /tmp/vbox"
        exit 1
    }
    mount -o loop $HOME_DIR/$ISO /tmp/vbox || true
    test -f /tmp/vbox/VBoxLinuxAdditions.run || {
        echo "could not mount $HOME_DIR/$ISO on /tmp/vbox"
        exit 1
    }

    echo "installing deps necessary to compile kernel modules"
    # We install things like kernel-headers here vs. kickstart files so we make sure we install them for the updated kernel not the stock kernel
    if [ -f "/bin/dnf" ]; then
        set +e
        (
            set -e
            dnf install -v -d 5 -y --skip-broken perl cpp gcc make bzip2 tar kernel-headers kernel-devel libX11 libXt libXext libXmu # not all these packages are on every system
        )
        DNF_EXIT=$?
        set -e
        if [ "$DNF_EXIT" -ne 0 ]; then
            echo "dnf exited with code $DNF_EXIT — continuing anyway"
        else
            echo "installed deps necessary to compile kernel modules using dnf"
        fi
    elif [ -f "/bin/yum" ] || [ -f "/usr/bin/yum" ]; then
        yum install -y --skip-broken perl cpp gcc make bzip2 tar kernel-headers kernel-devel libX11 libXt libXext libXmu || true # not all these packages are on every system
        echo "installed deps necessary to compile kernel modules using yum"
    elif [ -f "/usr/bin/apt-get" ]; then
        apt-get install -y build-essential dkms bzip2 tar linux-headers-`uname -r` libxt6 libxmu6
        echo "installed deps necessary to compile kernel modules using apt-get"
    elif [ -f "/usr/bin/zypper" ]; then
        zypper install -y perl cpp gcc make bzip2 tar kernel-default-devel
        echo "installed deps necessary to compile kernel modules using zypper"
    fi

    echo "installing the vbox additions"
    # this install script fails with non-zero exit codes for no apparent reason so we need better ways to know if it worked
    /tmp/vbox/VBoxLinuxAdditions.run --nox11 || true

    if ! modinfo vboxsf >/dev/null 2>&1; then
         echo "Cannot find vbox kernel module. Installation of guest additions unsuccessful!"
         exit 1
    fi

    echo "unmounting and removing the vbox ISO"
    umount /tmp/vbox
    rm -rf /tmp/vbox
    rm -f $HOME_DIR/*.iso

    echo "removing kernel dev packages and compilers we no longer need"
    if [ -f "/bin/dnf" ]; then
        dnf remove -y kernel-headers kernel-devel
    elif [ -f "/bin/yum" ] || [ -f "/usr/bin/yum" ]; then
        yum remove -y kernel-headers kernel-devel
    elif [ -f "/usr/bin/apt-get" ]; then
        apt-get remove -y dkms linux-headers-`uname -r`
    elif [ -f "/usr/bin/zypper" ]; then
        zypper -n rm -u kernel-default-devel gcc make
    fi

    echo "removing leftover logs"
    rm -rf /var/log/vboxadd*
  ;;
esac
