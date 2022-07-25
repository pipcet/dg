$(BUILD)/debian/deb/Packages: | $(BUILD)/debian/deb/
	curl http://http.us.debian.org/debian/dists/sid/main/binary-arm64/Packages.xz | xzcat > $@
	curl http://http.us.debian.org/debian/dists/sid/main/binary-all/Packages.xz | xzcat >> $@

$(BUILD)/debian/deb/%.deb: $(BUILD)/debian/deb/Packages dg/deb.pl | $(BUILD)/debian/deb/
	curl http://http.us.debian.org/debian/$(shell perl dg/deb.pl "$*" < $<) > $@

$(BUILD)/debian/deb/linux-image.deb: $(BUILD)/debian/deb/Packages dg/deb.pl | $(BUILD)/debian/deb/
	FILE=$$(egrep '^Package: linux-image-(.*)-cloud-arm64-unsigned' < $< | head -1 | while read DUMMY PACKAGE; do echo $$PACKAGE; done).deb; $(MAKE) -f dg/dg.mk $(BUILD)/debian/deb/$$FILE; ln -sf $$FILE $@

$(BUILD)/qemu-kernel: $(BUILD)/debian/deb/linux-image.deb
	$(MKDIR) $(BUILD)/kernel
	dpkg --extract $< $(BUILD)/kernel
	cp $(BUILD)/kernel/boot/vmlinuz* $@
