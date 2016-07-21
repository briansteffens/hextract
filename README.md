hextract
========

Print a sequence of bytes from a file to the console in hex format.

### Download and install:

```bash
git clone https://github.com/briansteffens/hextract
cd hextract
make
sudo make install
```

### Usage:

Print a complete file's contents:

```bash
hextract somefile
```

Print the first 5 bytes of a file:

```bash
hextract somefile -c 5
```

Print 7 bytes of a file, starting at an offset of 3:

```bash
hextract somefile -o 3 -c 7
```

Print all but the first 10 bytes of a file:

```bash
hextract somefile -o 10
```
