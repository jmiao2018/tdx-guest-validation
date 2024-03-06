#!/usr/bin/env python
"""Send get version"""
import os , struct
from mei import *

def req_get_restore_point_image(fd):
    buf_write = struct.pack("I", 0x00000018)
    return os.write(fd, buf_write)

def res_get_restore_point_image(fd):
    buf = os.read(fd, 0x5000)
    addr=0
    while buf:
        dw = buf[:4]
        buf = buf[4:]
        print "%08d:%s" % (addr, dw.encode('hex'))
        addr = addr + 4

def connect_fwu(fd):
    fwu = "309dcde8-ccb1-4062-8f78-600115a34327"
    return connect(fd, fwu)


if __name__ == '__main__':

    fd = open_dev_default()

    maxlen, vers = connect_fwu(fd)
    req_get_restore_point_image(fd)
    res_get_restore_point_image(fd)
    os.close(fd)

