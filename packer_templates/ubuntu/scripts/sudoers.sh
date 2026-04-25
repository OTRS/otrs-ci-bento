#!/bin/sh -eux

# Get the major version (like "26" from the version string (like "26.04")
major_version=$(lsb_release -r | cut -f 2 | cut -d . -f 1)

# Set up password-less sudo for the vagrant user
if [ -n "$major_version" -a "$major_version" -lt 26 ] ; then
    sed -i -e '/Defaults\s\+env_reset/a Defaults\texempt_group=sudo' /etc/sudoers;
    echo 'vagrant ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/99_vagrant;
else
    cat - <<EOF > /etc/sudoers.d/99_vagrant
Defaults:%sudo !secure_path
Defaults:%sudo env_keep += "PATH HOME_DIR PACKER_BUILDER_TYPE"
vagrant ALL=(ALL) NOPASSWD:ALL
EOF
fi

chmod 440 /etc/sudoers.d/99_vagrant;
