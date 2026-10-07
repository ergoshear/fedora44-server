fedora_ver := "44"
iso_name := "Fedora-Server-dvd-x86_64-44-1.7.iso"
iso_url := "https://download.fedoraproject.org/pub/fedora/linux/releases/44/Server/x86_64/iso"
checksum_name := "Fedora-Server-44-1.7-x86_64-CHECKSUM"

iso_in := "iso/" + iso_name
iso_out := "iso/ks-fedora44.iso"
ks := "kickstart/ks.cfg"
usb := "/dev/sdc"
salt_repo_url := "https://github.com/saltstack/salt-install-guide/releases/latest/download/salt.repo"
salt_section := "salt-repo-3008-lts"

default:
    @just --list

# Install host tools
deps:
    sudo dnf install -y lorax xorriso createrepo_c dnf-plugins-core pykickstart

# Download the Fedora Server DVD ISO and verify its checksum
download-iso:
    mkdir -p iso
    curl -fL -C - -o {{iso_in}} {{iso_url}}/{{iso_name}}
    curl -fL -o iso/{{checksum_name}} {{iso_url}}/{{checksum_name}}
    cd iso && sha256sum -c --ignore-missing {{checksum_name}}

# Validate the kickstart syntax
check:
    ksvalidator {{ks}}

# Download Salt RPMs and generate local repo metadata
salt-repo:
    rm -rf build/salt-repo build/reposdir
    mkdir -p build/salt-repo build/reposdir
    curl -fsSL {{salt_repo_url}} -o build/salt.repo
    sed -n '/^\[{{salt_section}}\]/,/^$/p' build/salt.repo > build/reposdir/salt.repo
    dnf download --destdir build/salt-repo --setopt=reposdir=build/reposdir --repo {{salt_section}} --releasever={{fedora_ver}} --arch x86_64 --arch noarch salt salt-minion
    createrepo_c build/salt-repo

# Build the kickstart ISO
iso: check
    sudo rm -f {{iso_out}}
    sudo mkksiso --ks {{ks}} --add build/salt-repo {{iso_in}} {{iso_out}}

# Write the ISO to the whole USB disk (destroys all data on it)
write:
    @lsblk -o NAME,SIZE,MODEL,TRAN {{usb}}
    @read -p "Erase {{usb}}? Type 'yes': " a && [ "$a" = yes ]
    -sudo umount {{usb}}?* 2>/dev/null
    sudo dd if={{iso_out}} of={{usb}} bs=4M conv=fsync oflag=direct status=progress
    sync
    sudo eject {{usb}}

# Rebuild ISO and write USB
usb: iso write

# Refresh Salt RPMs, then rebuild ISO and write USB
all: salt-repo iso write
