all: build

build:
	if [ ! -d "./libbasm" ]; then \
		git clone https://github.com/briansteffens/libbasm; \
	fi
	cd libbasm && git pull && make && ./build.py str_len str_to_int byte_to_hex
	mkdir -p bin
	nasm -f elf64 hextract.asm -o bin/hextract.o
	ld bin/hextract.o libbasm/bin/libbasm.a -o bin/hextract

install:
	mkdir -p ${DESTDIR}/usr/bin
	cp bin/hextract ${DESTDIR}/usr/bin/hextract

clean:
	rm -r bin
