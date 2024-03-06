#!/usr/bin/env python
"""Send get version"""
from mei import *

if __name__ == '__main__':

    fd = open_dev_default()

    try:
        connect_mkhi(fd)
    except IOError as e:
        if e.errno == 25:
            print "Errro: Cannot find MKHI Client"
            exit(1)
        else:
            raise e

    ver(fd)
    os.close(fd)

