#!/usr/bin/env python

import sys
from time import sleep
from argparse import ArgumentParser
from threading import Thread, Event

from serial import Serial, SerialTimeoutException


def print_start_info(info):
    print('Start testing: {}'.format(info))


def send_data(sdev, data, interval, e_end, e_timeout):
    # Sleep 2s waiting for reciving action
    sleep(2)
    for char in data:
        try:
            sdev.write(char.encode())
        except SerialTimeoutException:
            e_timeout.set()
            sys.exit()
        sleep(interval)
    e_end.set()


def transmit_data(indev, outdev, baudrate, interval, string):
    print_start_info(
        'Transmiting [{} --> {}], rate: {}'.format(indev, outdev, baudrate)
    )
    ser_in = Serial(indev, timeout=1)
    ser_in.flushInput()
    ser_in.baudrate = baudrate
    ser_out = Serial(outdev, timeout=1)
    ser_out.flushInput()
    ser_out.baudrate = baudrate

    data_in = list(string)
    data_out = []

    event_end = Event()
    event_timeout = Event()
    send_t = Thread(target=send_data,
                    args=(ser_in, data_in, interval,
                          event_end, event_timeout))
    send_t.start()

    while True:
        try:
            char = ser_out.read(1).decode()
        except SerialTimeoutException:
            print('Timeout when receiving data.')
            sys.exit(1)
        data_out.append(char)
        print('Receive "{}" from {}'.format(char, indev))
        if event_timeout.is_set():
            print('Timeout when sending data.')
            sys.exit(1)
        if event_end.is_set():
            break

    ser_in.close()
    ser_out.close()

    if ''.join(data_in) not in ''.join(data_out):
        print('Send: {}, Receive: {}, test failed.'.format(
            ''.join(data_in), ''.join(data_out))
        )
        sys.exit(1)

    print('Send: {}, Receive: {}, test passed.'.format(
        ''.join(data_in), ''.join(data_out))
    )


TEST_TYPES = {
    'transmit': transmit_data
}


def main():
    parser = ArgumentParser()
    parser.add_argument('-t', dest='type', default=None, help='test type.')
    parser.add_argument('-i', dest='input', default=None,
                        help='input device.')
    parser.add_argument('-o', dest='output', default=None,
                        help='output device.')
    parser.add_argument('-I', dest='interval', default=0.1, help='interval.')
    parser.add_argument('-b', dest='baudrate', default=115200, help='baudrate')
    parser.add_argument('-S', dest='string',
                        default='Hello, Linux Uart.',
                        help='string to send.')
    args = parser.parse_args()

    if args.type is None:
        print('No test type is given.')
        sys.exit(2)

    if args.input is None or args.output is None:
        print('No device is given.')
        sys.exit(2)

    if args.baudrate is None:
        print('No baudrate is given.')
        sys.exit(2)

    TEST_TYPES[args.type.strip()](
        args.input, args.output,
        int(args.baudrate),
        float(args.interval),
        args.string
    )


if __name__ == '__main__':
    main()
