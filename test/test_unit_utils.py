#!/usr/bin/env python

"""Unit test driver for checkout_externals

Note: this script assume the path to the checkout_externals.py module is
already in the python path.

"""

from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import unittest

from manic.utils import str_to_bool


class TestStrToBool(unittest.TestCase):
    """Test the string to boolean conversion routine.

    """

    def test_case_insensitive_true(self):
        """Verify that case insensitive variants of 'true' returns the True
        boolean.

        """
        values = ['true', 'TRUE', 'True', 'tRuE', 't', 'T', ]
        for value in values:
            received = str_to_bool(value)
            self.assertTrue(received)

    def test_case_insensitive_false(self):
        """Verify that case insensitive variants of 'false' returns the False
        boolean.

        """
        values = ['false', 'FALSE', 'False', 'fAlSe', 'f', 'F', ]
        for value in values:
            received = str_to_bool(value)
            self.assertFalse(received)

    def test_invalid_str_error(self):
        """Verify that a non-true/false string generates a runtime error.
        """
        values = ['not_true_or_false', 'A', '1', '0',
                  'false_is_not_true', 'true_is_not_false']
        for value in values:
            with self.assertRaises(RuntimeError):
                str_to_bool(value)


if __name__ == '__main__':
    unittest.main()
