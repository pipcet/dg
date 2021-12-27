PACKAGE ?= package
SELFURL ?= https://github.com/pipcet/debian-$(PACKAGE)
CROSS_COMPILE ?= aarch64-linux-gnu-
MKDIR ?= mkdir -p
CP ?= cp
CAT ?= cat
TAR ?= tar
PWD = $(shell pwd)
SUDO ?= $(and $(filter pip,$(shell whoami)),sudo)
NATIVE_TRIPLE ?= amd64-linux-gnu
BUILD ?= $(PWD)/dg/build

.SECONDEXPANSION:

all:

%/:
	$(MKDIR) $@

dg/build/%: $(PWD)/dg/build/%
	@true

%.gz: %
	gzip < $< > $@

%.xz: %
	xzcat -z --verbose < $< > $@

%.zstd: %
	zstd -cv < $< > $@

.PHONY: %}

include dg/github/github.mk
include dg/deb.mk

$(BUILD)/debian/root1.cpio.gz: | $(BUILD)/debian/
	wget -O $@ https://github.com/pipcet/debian-rootfs/releases/latest/download/root1.cpio.gz

$(BUILD)/debian/script.bash: | $(BUILD)/debian/
	(echo "#!/bin/bash -x"; \
	echo "ln -sf /usr/bin/true /usr/bin/mandb"; \
	echo "echo deb-src https://deb.debian.org/debian sid main >> /etc/apt/sources.list"; \
	echo "apt -y --fix-broken install"; \
	echo "apt-get -y update"; \
	echo "apt-get -y dist-upgrade"; \
	echo "apt-get -y install ca-certificates || true"; \
	echo "apt-get -y build-dep $(PACKAGE)"; \
	echo "apt-get install ca-certificates"; \
	echo "apt-get clean"; \
	echo "cd /root; git clone $(SELFURL) $(PACKAGE)"; \
	echo "cd /root/$(PACKAGE); ./debian/rules build"; \
	echo "cd /root/$(PACKAGE); ./debian/rules binary"; \
	echo "cd /root; tar cv *.udeb | uuencode packages.tar > /dev/vda") > $@

$(BUILD)/packages.tar: $(BUILD)/debian/script.bash $(BUILD)/qemu-kernel $(BUILD)/debian/root1.cpio.gz | $(BUILD)/
	dd if=/dev/zero of=tmp bs=128M count=1
	uuencode /dev/stdout < $< | dd conv=notrunc of=tmp
	qemu-system-aarch64 -drive if=virtio,index=0,media=disk,driver=raw,file=tmp -machine virt -cpu max -kernel $(BUILD)/qemu-kernel -m 7g -serial stdio -initrd $(BUILD)/debian/root1.cpio.gz -nic user,model=virtio -monitor none -smp 8 -nographic
	uudecode -o $@ < tmp
	tar xvf $@
	rm -f tmp

{release-udeb}: $(addsuffix $(wildcard dg/build/$(PACKAGE)*.udeb),{release})
