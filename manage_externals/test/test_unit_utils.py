#!/usr/bin/env python

"""Unit test driver for checkout_externals

Note: this script assume the path to the checkout_externals.py module is
already in the python path.

"""

from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import os
import unittest

from manic.utils import last_n_lines, indent_string
from manic.utils import str_to_bool, execute_subprocess
from manic.utils import is_remote_url, split_remote_url, expand_local_url


class TestExecuteSubprocess(unittest.TestCase):
    """Test the application logic of execute_subprocess wrapper
    """

    def test_exesub_return_stat_err(self):
        """Test that execute_subprocess returns a status code when caller
        requests and the executed subprocess fails.

        """
        cmd = ['false']
        status = execute_subprocess(cmd, status_to_caller=True)
        self.assertEqual(status, 1)

    def test_exesub_return_stat_ok(self):
        """Test that execute_subprocess returns a status code when caller
        requests and the executed subprocess succeeds.

        """
        cmd = ['true']
        status = execute_subprocess(cmd, status_to_caller=True)
        self.assertEqual(status, 0)

    def test_exesub_except_stat_err(self):
        """Test that execute_subprocess raises an exception on error when
        caller doesn't request return code

        """
        cmd = ['false']
        with self.assertRaises(RuntimeError):
            execute_subprocess(cmd, status_to_caller=False)


class TestLastNLines(unittest.TestCase):
    """Test the last_n_lines function.

    """

    def test_last_n_lines_short(self):
        """With a message with <= n lines, result of last_n_lines should
        just be the original message.

        """
        mystr = """three
line
string
"""

        mystr_truncated = last_n_lines(
            mystr, 3, truncation_message='[truncated]')
        self.assertEqual(mystr, mystr_truncated)

    def test_last_n_lines_long(self):
        """With a message with > n lines, result of last_n_lines should
        be a truncated string.

        """
        mystr = """a
big
five
line
string
"""
        expected = """[truncated]
five
line
string
"""

        mystr_truncated = last_n_lines(
            mystr, 3, truncation_message='[truncated]')
        self.assertEqual(expected, mystr_truncated)


class TestIndentStr(unittest.TestCase):
    """Test the indent_string function.

    """

    def test_indent_string_singleline(self):
        """Test the indent_string function with a single-line string

        """
        mystr = 'foo'
        result = indent_string(mystr, 4)
        expected = '    foo'
        self.assertEqual(expected, result)

    def test_indent_string_multiline(self):
        """Test the indent_string function with a multi-line string

        """
        mystr = """hello
hi
goodbye
"""
        result = indent_string(mystr, 2)
        expected = """  hello
  hi
  goodbye
"""
        self.assertEqual(expected, result)


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


class TestIsRemoteURL(unittest.TestCase):
    """Crude url checking to determine if a url is local or remote.

    """

    def test_url_remote_git(self):
        """verify that a remote git url is identified.
        """
        url = 'git@somewhere'
        is_remote = is_remote_url(url)
        self.assertTrue(is_remote)

    def test_url_remote_ssh(self):
        """verify that a remote ssh url is identified.
        """
        url = 'ssh://user@somewhere'
        is_remote = is_remote_url(url)
        self.assertTrue(is_remote)

    def test_url_remote_http(self):
        """verify that a remote http url is identified.
        """
        url = 'http://somewhere'
        is_remote = is_remote_url(url)
        self.assertTrue(is_remote)

    def test_url_remote_https(self):
        """verify that a remote https url is identified.
        """
        url = 'https://somewhere'
        is_remote = is_remote_url(url)
        self.assertTrue(is_remote)

    def test_url_local_user(self):
        """verify that a local path with '~/path/to/repo' gets rejected

        """
        url = '~/path/to/repo'
        is_remote = is_remote_url(url)
        self.assertFalse(is_remote)

    def test_url_local_var_curly(self):
        """verify that a local path with env var '${HOME}' gets rejected
        """
        url = '${HOME}/path/to/repo'
        is_remote = is_remote_url(url)
        self.assertFalse(is_remote)

    def test_url_local_var(self):
        """verify that a local path with an env var '$HOME' gets rejected
        """
        url = '$HOME/path/to/repo'
        is_remote = is_remote_url(url)
        self.assertFalse(is_remote)

    def test_url_local_abs(self):
        """verify that a local abs path gets rejected
        """
        url = '/path/to/repo'
        is_remote = is_remote_url(url)
        self.assertFalse(is_remote)

    def test_url_local_rel(self):
        """verify that a local relative path gets rejected
        """
        url = '../../path/to/repo'
        is_remote = is_remote_url(url)
        self.assertFalse(is_remote)


class TestSplitRemoteURL(unittest.TestCase):
    """Crude url checking to determine if a url is local or remote.

    """

    def test_url_remote_git(self):
        """verify that a remote git url is identified.
        """
        url = 'git@somewhere.com:org/repo'
        received = split_remote_url(url)
        self.assertEqual(received, "org/repo")

    def test_url_remote_ssh(self):
        """verify that a remote ssh url is identified.
        """
        url = 'ssh://user@somewhere.com/path/to/repo'
        received = split_remote_url(url)
        self.assertEqual(received, 'somewhere.com/path/to/repo')

    def test_url_remote_http(self):
        """verify that a remote http url is identified.
        """
        url = 'http://somewhere.org/path/to/repo'
        received = split_remote_url(url)
        self.assertEqual(received, 'somewhere.org/path/to/repo')

    def test_url_remote_https(self):
        """verify that a remote http url is identified.
        """
        url = 'http://somewhere.gov/path/to/repo'
        received = split_remote_url(url)
        self.assertEqual(received, 'somewhere.gov/path/to/repo')

    def test_url_local_url_unchanged(self):
        """verify that a local path is unchanged

        """
        url = '/path/to/repo'
        received = split_remote_url(url)
        self.assertEqual(received, url)


class TestExpandLocalURL(unittest.TestCase):
    """Crude url checking to determine if a url is local or remote.

    Remote should be unmodified.

    Local, should perform user and variable expansion.

    """

    def test_url_local_user1(self):
        """verify that a local path with '~/path/to/repo' gets expanded to an
        absolute path.

        NOTE(bja, 2017-11) we can't test for something like:
        '~user/path/to/repo' because the user has to be in the local
        machine password directory and we don't know a user name that
        is valid on every system....?

        """
        field = 'test'
        url = '~/path/to/repo'
        received = expand_local_url(url, field)
        print(received)
        self.assertTrue(os.path.isabs(received))

    def test_url_local_expand_curly(self):
        """verify that a local path with '${HOME}' gets expanded to an absolute path.
        """
        field = 'test'
        url = '${HOME}/path/to/repo'
        received = expand_local_url(url, field)
        self.assertTrue(os.path.isabs(received))

    def test_url_local_expand_var(self):
        """verify that a local path with '$HOME' gets expanded to an absolute path.
        """
        field = 'test'
        url = '$HOME/path/to/repo'
        received = expand_local_url(url, field)
        self.assertTrue(os.path.isabs(received))

    def test_url_local_env_missing(self):
        """verify that a local path with env var that is missing gets left as-is

        """
        field = 'test'
        url = '$TMP_VAR/path/to/repo'
        received = expand_local_url(url, field)
        print(received)
        self.assertEqual(received, url)

    def test_url_local_expand_env(self):
        """verify that a local path with another env var gets expanded to an
        absolute path.

        """
        field = 'test'
        os.environ['TMP_VAR'] = '/some/absolute'
        url = '$TMP_VAR/path/to/repo'
        received = expand_local_url(url, field)
        del os.environ['TMP_VAR']
        print(received)
        self.assertTrue(os.path.isabs(received))
        self.assertEqual(received, '/some/absolute/path/to/repo')

    def test_url_local_normalize_rel(self):
        """verify that a local path with another env var gets expanded to an
        absolute path.

        """
        field = 'test'
        url = '/this/is/a/long/../path/to/a/repo'
        received = expand_local_url(url, field)
        print(received)
        self.assertEqual(received, '/this/is/a/path/to/a/repo')


if __name__ == '__main__':
    unittest.main()
