#!/usr/bin/env python
"""Send data rapidly  get version"""
import os
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
    os.close(fd)

    for n in range(0, 2000):
        fd = open_dev_default()
        maxlen, vers = connect_mkhi(fd)
        ver(fd)
        os.close(fd)
