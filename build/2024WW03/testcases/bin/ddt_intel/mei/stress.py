#!/usr/bin/env python
"Send data rapidly to ME clients"
import os
from mei import *

if __name__ == '__main__':

    try:
        uuid_str = sys.argv[1]
    except IndexError as e:
        print "Usage: stress.py <uuid>"
        exit(1)


    fd = open_dev_default()
    try:
        connect(fd, uuid_str)
    except IOError as e:
        if e.errno == 25:
            print "Errro: Cannot find MKHI Client"
            exit(1)
        else:
            raise e
    os.close(fd)

    data = "A"
    for n in range(0, 3000):
        fd = open_dev_default()
        maxlen, vers = connect(fd, uuid_str)
        os.write(fd, data)
        os.close(fd)
