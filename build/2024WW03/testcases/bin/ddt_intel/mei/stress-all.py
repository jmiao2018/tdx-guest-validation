#!/usr/bin/env python
"Send data rapidly to ME clients"
import os
from mei import *
from mei.debugfs import meclients

if __name__ == '__main__':

    data = "A"
    devnode = dev_default()
    clients = meclients(devnode)
    for uuid_str in clients:
      for n in range(0, 3000):
        fd = open_dev_default()
        maxlen, vers = connect(fd, uuid_str)
        os.write(fd, data)
        os.close(fd)
