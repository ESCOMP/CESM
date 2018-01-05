#!/usr/bin/env python

"""Unit test driver for checkout_externals

Note: this script assume the path to the checkout_externals.py module is
already in the python path.

"""

from __future__ import absolute_import
from __future__ import unicode_literals
from __future__ import print_function

import unittest

from manic.repository_svn import SvnRepository
from manic.externals_status import ExternalStatus
from manic.externals_description import ExternalsDescription
from manic.externals_description import ExternalsDescriptionDict
from manic.global_constants import EMPTY_STR

# pylint: disable=W0212

SVN_INFO_MOSART = """Path: components/mosart
Working Copy Root Path: /Users/andreb/projects/ncar/git-conversion/clm-dev-experimental/components/mosart
URL: https://svn-ccsm-models.cgd.ucar.edu/mosart/trunk_tags/mosart1_0_26
Relative URL: ^/mosart/trunk_tags/mosart1_0_26
Repository Root: https://svn-ccsm-models.cgd.ucar.edu
Repository UUID: fe37f545-8307-0410-aea5-b40df96820b5
Revision: 86711
Node Kind: directory
Schedule: normal
Last Changed Author: erik
Last Changed Rev: 86031
Last Changed Date: 2017-07-07 12:28:10 -0600 (Fri, 07 Jul 2017)
"""
SVN_INFO_CISM = """
Path: components/cism
Working Copy Root Path: /Users/andreb/projects/ncar/git-conversion/clm-dev-experimental/components/cism
URL: https://svn-ccsm-models.cgd.ucar.edu/glc/trunk_tags/cism2_1_37
Relative URL: ^/glc/trunk_tags/cism2_1_37
Repository Root: https://svn-ccsm-models.cgd.ucar.edu
Repository UUID: fe37f545-8307-0410-aea5-b40df96820b5
Revision: 86711
Node Kind: directory
Schedule: normal
Last Changed Author: sacks
Last Changed Rev: 85704
Last Changed Date: 2017-06-15 05:59:28 -0600 (Thu, 15 Jun 2017)
"""


class TestSvnRepositoryCheckURL(unittest.TestCase):
    """Verify that the svn_check_url function is working as expected.
    """

    def setUp(self):
        """Setup reusable svn repository object
        """
        self._name = 'component'
        rdata = {ExternalsDescription.PROTOCOL: 'svn',
                 ExternalsDescription.REPO_URL:
                     'https://svn-ccsm-models.cgd.ucar.edu/',
                 ExternalsDescription.TAG:
                     'mosart/trunk_tags/mosart1_0_26',
                 ExternalsDescription.BRANCH: ''
                 }

        data = {self._name:
                {
                    ExternalsDescription.REQUIRED: False,
                    ExternalsDescription.PATH: 'junk',
                    ExternalsDescription.EXTERNALS: '',
                    ExternalsDescription.REPO: rdata,
                },
                }

        model = ExternalsDescriptionDict(data)
        repo = model[self._name][ExternalsDescription.REPO]
        self._repo = SvnRepository('test', repo)

    def test_check_url_same(self):
        """Test that we correctly identify that the correct URL.
        """
        svn_output = SVN_INFO_MOSART
        expected_url = self._repo.url()
        result, current_version = \
            self._repo._check_url(svn_output, expected_url)
        self.assertEqual(result, ExternalStatus.STATUS_OK)
        self.assertEqual(current_version, 'mosart/trunk_tags/mosart1_0_26')

    def test_check_url_different(self):
        """Test that we correctly reject an incorrect URL.
        """
        svn_output = SVN_INFO_CISM
        expected_url = self._repo.url()
        result, current_version = \
            self._repo._check_url(svn_output, expected_url)
        self.assertEqual(result, ExternalStatus.MODEL_MODIFIED)
        self.assertEqual(current_version, 'glc/trunk_tags/cism2_1_37')

    def test_check_url_none(self):
        """Test that we can handle an empty string for output, e.g. not an svn
        repo.

        """
        svn_output = EMPTY_STR
        expected_url = self._repo.url()
        result, current_version = \
            self._repo._check_url(svn_output, expected_url)
        self.assertEqual(result, ExternalStatus.UNKNOWN)
        self.assertEqual(current_version, '')


class TestSvnRepositoryCheckSync(unittest.TestCase):
    """Test whether the SvnRepository svn_check_sync functionality is
    correct.

    """

    def setUp(self):
        """Setup reusable svn repository object
        """
        self._name = "component"
        rdata = {ExternalsDescription.PROTOCOL: 'svn',
                 ExternalsDescription.REPO_URL:
                     'https://svn-ccsm-models.cgd.ucar.edu/',
                 ExternalsDescription.TAG:
                     'mosart/trunk_tags/mosart1_0_26',
                 ExternalsDescription.BRANCH: EMPTY_STR
                 }

        data = {self._name:
                {
                    ExternalsDescription.REQUIRED: False,
                    ExternalsDescription.PATH: 'junk',
                    ExternalsDescription.EXTERNALS: EMPTY_STR,
                    ExternalsDescription.REPO: rdata,
                },
                }

        model = ExternalsDescriptionDict(data)
        repo = model[self._name][ExternalsDescription.REPO]
        self._repo = SvnRepository('test', repo)

    @staticmethod
    def _svn_info_empty(*_):
        """Return an empty info string. Simulates svn info failing.
        """
        return ''

    @staticmethod
    def _svn_info_synced(*_):
        """Return an info sting that is synced with the setUp data
        """
        return SVN_INFO_MOSART

    @staticmethod
    def _svn_info_modified(*_):
        """Return and info string that is modified from the setUp data
        """
        return SVN_INFO_CISM

    def test_repo_dir_not_exist(self):
        """Test that a directory that doesn't exist returns an error status

        Note: the Repository classes should be prevented from ever
        working on an empty directory by the _Source object.

        """
        stat = ExternalStatus()
        self._repo._check_sync(stat, 'junk')
        self.assertEqual(stat.sync_state, ExternalStatus.STATUS_ERROR)
        # check_dir should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_repo_dir_exist_no_svn_info(self):
        """Test that an empty info string returns an unknown status
        """
        stat = ExternalStatus()
        # Now we over-ride the _svn_info method on the repo to return
        # a known value without requiring access to svn.
        self._repo._svn_info = self._svn_info_empty
        self._repo._check_sync(stat, '.')
        self.assertEqual(stat.sync_state, ExternalStatus.UNKNOWN)
        # check_dir should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_repo_dir_synced(self):
        """Test that a valid info string that is synced to the repo in the
        externals description returns an ok status.

        """
        stat = ExternalStatus()
        # Now we over-ride the _svn_info method on the repo to return
        # a known value without requiring access to svn.
        self._repo._svn_info = self._svn_info_synced
        self._repo._check_sync(stat, '.')
        self.assertEqual(stat.sync_state, ExternalStatus.STATUS_OK)
        # check_dir should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)

    def test_repo_dir_modified(self):
        """Test that a valid svn info string that is out of sync with the
        externals description returns a modified status.

        """
        stat = ExternalStatus()
        # Now we over-ride the _svn_info method on the repo to return
        # a known value without requiring access to svn.
        self._repo._svn_info = self._svn_info_modified
        self._repo._check_sync(stat, '.')
        self.assertEqual(stat.sync_state, ExternalStatus.MODEL_MODIFIED)
        # check_dir should only modify the sync_state, not clean_state
        self.assertEqual(stat.clean_state, ExternalStatus.DEFAULT)


class TestSVNStatusXML(unittest.TestCase):
    """Test parsing of svn status xml output
    """
    SVN_STATUS_XML_DIRTY_ALL = '''
<status>
<target
   path=".">
<entry
   path="ChangeLog">
<wc-status
   item="missing"
   revision="86711"
   props="none">
<commit
   revision="85703">
<author>sacks</author>
<date>2017-06-15T11:59:00.355419Z</date>
</commit>
</wc-status>
</entry>
<entry
   path="README.parallelization">
<wc-status
   props="none"
   item="modified"
   revision="86711">
<commit
   revision="43811">
<author>sacks</author>
<date>2013-02-07T16:17:56.412878Z</date>
</commit>
</wc-status>
</entry>
<entry
   path="SVN_EXTERNAL_DIRECTORIES">
<wc-status
   item="deleted"
   revision="86711"
   props="none">
<commit
   revision="84725">
<author>sacks</author>
<date>2017-05-01T16:48:27.893741Z</date>
</commit>
</wc-status>
</entry>
<entry
   path="glimmer-cism">
<wc-status
   item="external"
   props="none">
</wc-status>
</entry>
<entry
   path="junk.txt">
<wc-status
   item="unversioned"
   props="none">
</wc-status>
</entry>
<entry
   path="stuff.txt">
<wc-status
   props="none"
   item="added"
   revision="-1">
</wc-status>
</entry>
</target>
</status>'''

    SVN_STATUS_XML_DIRTY_MISSING = '''
<status>
<target
   path=".">
<entry
   path="ChangeLog">
<wc-status
   item="missing"
   revision="86711"
   props="none">
<commit
   revision="85703">
<author>sacks</author>
<date>2017-06-15T11:59:00.355419Z</date>
</commit>
</wc-status>
</entry>
<entry
   path="glimmer-cism">
<wc-status
   item="external"
   props="none">
</wc-status>
</entry>
</target>
</status>'''

    SVN_STATUS_XML_DIRTY_MODIFIED = '''
<status>
<target
   path=".">
<entry
   path="README.parallelization">
<wc-status
   props="none"
   item="modified"
   revision="86711">
<commit
   revision="43811">
<author>sacks</author>
<date>2013-02-07T16:17:56.412878Z</date>
</commit>
</wc-status>
</entry>
<entry
   path="glimmer-cism">
<wc-status
   item="external"
   props="none">
</wc-status>
</entry>
</target>
</status>'''

    SVN_STATUS_XML_DIRTY_DELETED = '''
<status>
<target
   path=".">
<entry
   path="SVN_EXTERNAL_DIRECTORIES">
<wc-status
   item="deleted"
   revision="86711"
   props="none">
<commit
   revision="84725">
<author>sacks</author>
<date>2017-05-01T16:48:27.893741Z</date>
</commit>
</wc-status>
</entry>
<entry
   path="glimmer-cism">
<wc-status
   item="external"
   props="none">
</wc-status>
</entry>
</target>
</status>'''

    SVN_STATUS_XML_DIRTY_UNVERSION = '''
<status>
<target
   path=".">
<entry
   path="glimmer-cism">
<wc-status
   item="external"
   props="none">
</wc-status>
</entry>
<entry
   path="junk.txt">
<wc-status
   item="unversioned"
   props="none">
</wc-status>
</entry>
</target>
</status>'''

    SVN_STATUS_XML_DIRTY_ADDED = '''
<status>
<target
   path=".">
<entry
   path="glimmer-cism">
<wc-status
   item="external"
   props="none">
</wc-status>
</entry>
<entry
   path="stuff.txt">
<wc-status
   props="none"
   item="added"
   revision="-1">
</wc-status>
</entry>
</target>
</status>'''

    SVN_STATUS_XML_CLEAN = '''
<status>
<target
   path=".">
<entry
   path="glimmer-cism">
<wc-status
   item="external"
   props="none">
</wc-status>
</entry>
<entry
   path="junk.txt">
<wc-status
   item="unversioned"
   props="none">
</wc-status>
</entry>
</target>
</status>'''

    def test_xml_status_dirty_missing(self):
        """Verify that svn status output is consindered dirty when there is a
        missing file.

        """
        svn_output = self.SVN_STATUS_XML_DIRTY_MISSING
        is_dirty = SvnRepository.xml_status_is_dirty(
            svn_output)
        self.assertTrue(is_dirty)

    def test_xml_status_dirty_modified(self):
        """Verify that svn status output is consindered dirty when there is a
        modified file.
        """
        svn_output = self.SVN_STATUS_XML_DIRTY_MODIFIED
        is_dirty = SvnRepository.xml_status_is_dirty(
            svn_output)
        self.assertTrue(is_dirty)

    def test_xml_status_dirty_deleted(self):
        """Verify that svn status output is consindered dirty when there is a
        deleted file.
        """
        svn_output = self.SVN_STATUS_XML_DIRTY_DELETED
        is_dirty = SvnRepository.xml_status_is_dirty(
            svn_output)
        self.assertTrue(is_dirty)

    def test_xml_status_dirty_unversion(self):
        """Verify that svn status output ignores unversioned files when making
        the clean/dirty decision.

        """
        svn_output = self.SVN_STATUS_XML_DIRTY_UNVERSION
        is_dirty = SvnRepository.xml_status_is_dirty(
            svn_output)
        self.assertFalse(is_dirty)

    def test_xml_status_dirty_added(self):
        """Verify that svn status output is consindered dirty when there is a
        added file.
        """
        svn_output = self.SVN_STATUS_XML_DIRTY_ADDED
        is_dirty = SvnRepository.xml_status_is_dirty(
            svn_output)
        self.assertTrue(is_dirty)

    def test_xml_status_dirty_all(self):
        """Verify that svn status output is consindered dirty when there are
        multiple dirty files..

        """
        svn_output = self.SVN_STATUS_XML_DIRTY_ALL
        is_dirty = SvnRepository.xml_status_is_dirty(
            svn_output)
        self.assertTrue(is_dirty)

    def test_xml_status_dirty_clean(self):
        """Verify that svn status output is consindered clean when there are
        no 'dirty' files. This means accepting untracked and externals.

        """
        svn_output = self.SVN_STATUS_XML_CLEAN
        is_dirty = SvnRepository.xml_status_is_dirty(
            svn_output)
        self.assertFalse(is_dirty)


if __name__ == '__main__':
    unittest.main()
