MODULES = halt_test.ko

obj-m += halt_test.o

all:
	make ARCH=x86_64 -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules
clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
