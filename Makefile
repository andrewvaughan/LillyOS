VERSION = 0.1a

iso: lillyos-$(VERSION).img
	mkisofs -b lillyos-$(VERSION).img -o lillyos-$(VERSION).iso ./

floppy: lillyos-$(VERSION).img
	mv lillyos-$(VERSION).img lillyos-$(VERSION).flp

lillyos-$(VERSION).img: dependencies
	dd if=/dev/zero of=lillyos-$(VERSION).img bs=512 count=2880
	dd conv=notrunc if=bootloader/bootloader.bin of=lillyos-$(VERSION).img

dependencies:
	+$(MAKE) -C bootloader

clean:
	+$(MAKE) -C bootloader clean

	rm -rf lillyos-$(VERSION).iso
	rm -rf lillyos-$(VERSION).flp
	rm -rf lillyos-$(VERSION).img

.PHONY: iso floppy dependencies clean
