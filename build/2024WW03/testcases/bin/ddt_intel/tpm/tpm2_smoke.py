#!/usr/bin/env python3
#
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2018-2020, Intel Corporation.

from argparse import ArgumentParser
from argparse import FileType
import os
import sys
import tpm2
from tpm2 import ProtocolError
import unittest
import logging
import struct


class SmokeTest(unittest.TestCase):
    def setUp(self):
        self.client = tpm2.Client()
        self.root_key = self.client.create_root_key()

    def tearDown(self):
        self.client.flush_context(self.root_key)
        self.client.close()

    def test_seal_with_auth(self):
        data = 'X' * 64
        auth = 'A' * 15

        blob = self.client.seal(self.root_key, data, auth, None)
        result = self.client.unseal(self.root_key, blob, auth, None)
        self.assertEqual(data, result.decode())

    def test_seal_with_policy(self):
        handle = self.client.start_auth_session(tpm2.TPM2_SE_TRIAL)

        data = 'X' * 64
        auth = 'A' * 15
        pcrs = [16]

        try:
            self.client.policy_pcr(handle, pcrs)
            self.client.policy_password(handle)

            policy_dig = self.client.get_policy_digest(handle)
        finally:
            self.client.flush_context(handle)

        blob = self.client.seal(self.root_key, data, auth, policy_dig)

        handle = self.client.start_auth_session(tpm2.TPM2_SE_POLICY)

        try:
            self.client.policy_pcr(handle, pcrs)
            self.client.policy_password(handle)

            result = self.client.unseal(self.root_key, blob, auth, handle)
        except:
            self.client.flush_context(handle)
            raise

        self.assertEqual(data, result.decode())

    def test_unseal_with_wrong_auth(self):
        data = 'X' * 64
        auth = 'A' * 20
        rc = 0

        blob = self.client.seal(self.root_key, data, auth, None)
        try:
            result = self.client.unseal(self.root_key,
                                        blob, auth[:-1] + 'B', None)
        except ProtocolError as e:
            rc = e.rc

        self.assertEqual(rc, tpm2.TPM2_RC_AUTH_FAIL)

    def test_unseal_with_wrong_policy(self):
        handle = self.client.start_auth_session(tpm2.TPM2_SE_TRIAL)

        data = 'X' * 64
        auth = 'A' * 17
        pcrs = [16]

        try:
            self.client.policy_pcr(handle, pcrs)
            self.client.policy_password(handle)

            policy_dig = self.client.get_policy_digest(handle)
        finally:
            self.client.flush_context(handle)

        blob = self.client.seal(self.root_key, data, auth, policy_dig)

        # Extend first a PCR that is not part of the policy and try to unseal.
        # This should succeed.

        ds = tpm2.get_digest_size(tpm2.TPM2_ALG_SHA1)
        self.client.extend_pcr(1, 'X' * ds)

        handle = self.client.start_auth_session(tpm2.TPM2_SE_POLICY)

        try:
            self.client.policy_pcr(handle, pcrs)
            self.client.policy_password(handle)

            result = self.client.unseal(self.root_key, blob, auth, handle)
        except:
            self.client.flush_context(handle)
            raise

        self.assertEqual(data, result.decode())

        # Then, extend a PCR that is part of the policy and try to unseal.
        # This should fail.
        self.client.extend_pcr(16, 'X' * ds)

        handle = self.client.start_auth_session(tpm2.TPM2_SE_POLICY)

        rc = 0

        try:
            self.client.policy_pcr(handle, pcrs)
            self.client.policy_password(handle)

            result = self.client.unseal(self.root_key, blob, auth, handle)
        except ProtocolError as e:
            rc = e.rc
            self.client.flush_context(handle)
        except:
            self.client.flush_context(handle)
            raise

        self.assertEqual(rc, tpm2.TPM2_RC_POLICY_FAIL)

    def test_seal_with_too_long_auth(self):
        ds = tpm2.get_digest_size(tpm2.TPM2_ALG_SHA1)
        data = 'X' * 64
        auth = 'A' * (ds + 1)

        rc = 0
        try:
            blob = self.client.seal(self.root_key, data, auth, None)
        except ProtocolError as e:
            rc = e.rc

        self.assertEqual(rc, tpm2.TPM2_RC_SIZE)

    def test_too_short_cmd(self):
        rejected = False
        try:
            fmt = '>HIII'
            cmd = struct.pack(fmt,
                              tpm2.TPM2_ST_NO_SESSIONS,
                              struct.calcsize(fmt) + 1,
                              tpm2.TPM2_CC_FLUSH_CONTEXT,
                              0xDEADBEEF)

            self.client.send_cmd(cmd)
        except IOError as e:
            rejected = True
        except:
            pass
        self.assertEqual(rejected, True)


class SpaceTest(unittest.TestCase):
    def setUp(self):
        logging.basicConfig(filename='SpaceTest.log', level=logging.DEBUG)

    def test_make_two_spaces(self):
        log = logging.getLogger(__name__)
        log.debug("test_make_two_spaces")

        space1 = tpm2.Client(tpm2.Client.FLAG_SPACE)
        root1 = space1.create_root_key()
        space2 = tpm2.Client(tpm2.Client.FLAG_SPACE)
        root2 = space2.create_root_key()
        root3 = space2.create_root_key()

        log.debug("%08x" % (root1))
        log.debug("%08x" % (root2))
        log.debug("%08x" % (root3))

    def test_flush_context(self):
        log = logging.getLogger(__name__)
        log.debug("test_flush_context")

        space1 = tpm2.Client(tpm2.Client.FLAG_SPACE)
        root1 = space1.create_root_key()
        log.debug("%08x" % (root1))

        space1.flush_context(root1)

    def test_get_handles(self):
        log = logging.getLogger(__name__)
        log.debug("test_get_handles")

        space1 = tpm2.Client(tpm2.Client.FLAG_SPACE)
        space1.create_root_key()
        space2 = tpm2.Client(tpm2.Client.FLAG_SPACE)
        space2.create_root_key()
        space2.create_root_key()

        handles = space2.get_cap(tpm2.TPM2_CAP_HANDLES, tpm2.HR_TRANSIENT)

        self.assertEqual(len(handles), 2)

        log.debug("%08x" % (handles[0]))
        log.debug("%08x" % (handles[1]))

    def test_invalid_cc(self):
        log = logging.getLogger(__name__)
        log.debug(sys._getframe().f_code.co_name)

        TPM2_CC_INVALID = tpm2.TPM2_CC_FIRST - 1

        space1 = tpm2.Client(tpm2.Client.FLAG_SPACE)
        root1 = space1.create_root_key()
        log.debug("%08x" % (root1))

        fmt = '>HII'
        cmd = struct.pack(fmt, tpm2.TPM2_ST_NO_SESSIONS, struct.calcsize(fmt),
                          TPM2_CC_INVALID)

        rc = 0
        try:
            space1.send_cmd(cmd)
        except ProtocolError as e:
            rc = e.rc

        self.assertEqual(rc, tpm2.TPM2_RC_COMMAND_CODE |
                         tpm2.TSS2_RESMGR_TPM_RC_LAYER)
