VERSION = 0.1a

iso: image
	mkisofs -b lillyos-$(VERSION).img -o lillyos-$(VERSION).iso ./

image: lillyos-$(VERSION).img

lillyos-$(VERSION).img: dependencies
	dd if=/dev/zero of=lillyos-$(VERSION).img bs=512 count=2880
	dd conv=notrunc if=bootloader/bootloader.bin of=lillyos-$(VERSION).img

emulation: image
	qemu-system-i386 -m 1024 -cpu qemu32 -drive file=lillyos-$(VERSION).img,index=0,media=disk,format=raw

dependencies:
	+$(MAKE) -C bootloader

clean:
	+$(MAKE) -C bootloader clean

	rm -rf lillyos-$(VERSION).iso
	rm -rf lillyos-$(VERSION).img

.PHONY: iso image emulation dependencies clean
