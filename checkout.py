#!/usr/bin/env python

"""
Tool to assemble respositories represented in a model-description file.

If loaded as a module (e.g., in a component's buildcpp), it can be used
to check the validity of existing subdirectories and load missing sources.
"""

import sys
import os
import os.path
import errno
import inspect
import re
import xml.etree.ElementTree as ET
import subprocess
import urllib
import argparse

## Common regular expressions
reNamespace    = re.compile("{[^}]*}")
reUrlLine      = re.compile("^URL:")
reGitHash      = re.compile("\A([a-fA-F0-9]+)\Z")
reRemoteBranch = re.compile("\s*origin/(\S+)")

###############################################################################
def perr(errstr):
###############################################################################
    """
    Error output function
    """
    print "{0}ERROR: {1}".format(os.linesep, errstr)
    exit(-1)

###
## Process execution helper functions -- don't really belong here
###
###############################################################################
def checkOutput(commands):
###############################################################################
    """
    Wrapper around subprocess.check_output to handle common exceptions.
    check_output runs a command with arguments and returns its output.
    On successful completion, checkOutput returns the command's output.
    """
    try:
        outstr = subprocess.check_output(commands)
    except OSError as e:
        print >>sys.stderr, "Execution of '{}' failed:".format((' '.join(commands)), e)
    except ValueError as e:
        print >>sys.stderr, "ValueError in '{}':".format((' '.join(commands)), e)
        outstr = None
    except subprocess.CalledProcessError as e:
        print >>sys.stderr, "CalledProcessError in '{}':".format((' '.join(commands)), e)
        outstr = None

    return outstr


###############################################################################
def scall(commands):
###############################################################################
    """
    Wrapper around subprocess.check_call to handle common exceptions.
    check_call runs a command with arguments and waits for it to complete.
    check_call raises an exception on a nonzero return code.
    scall returns the return code of the command (zero) or -1 on error.
    """
    retcode = -1
    try:
        retcode = subprocess.check_call(commands)
    except OSError as e:
        print >>sys.stderr, "Execution of '{}' failed".format((' '.join(commands)))
        print >>sys.stderr,  e
    except ValueError as e:
        print >>sys.stderr, "ValueError in '{}'".format((' '.join(commands)))
        print >>sys.stderr,  e
    except subprocess.CalledProcessError as e:
        print >>sys.stderr, "CalledProcessError in '{}'".format((' '.join(commands)))
        print >>sys.stderr,  e

    return retcode


###############################################################################
def retcall(commands):
###############################################################################
    """
    Wrapper around subprocess.call to handle common exceptions.
    call runs a command with arguments, waits for it to complete, and returns
    the command's return code.
    retcall sends all error output to /dev/null and is used when just the
    return code is desired.
    """
    FNULL = open(os.devnull, 'w')
    try:
        retcode = subprocess.call(commands, stdout=FNULL, stderr=subprocess.STDOUT)
    except OSError as e:
        print >>sys.stderr, "Execution of '%s' failed"%(' '.join(commands))
        print >>sys.stderr,  e
    except ValueError as e:
        print >>sys.stderr, "ValueError in '%s'"%(' '.join(commands))
        print >>sys.stderr,  e
    except subprocess.CalledProcessError as e:
        print >>sys.stderr, "CalledProcessError in '%s'"%(' '.join(commands))
        print >>sys.stderr,  e

    FNULL.close()
    return retcode


###############################################################################
def quitOnFail(retcode, caller):
###############################################################################
    """
    Check a return code and exit if non-zero.
    """
    if retcode != 0:
        print >>sys.stderr, "%s failed with return code %d"%(caller, retcode)
        exit(retcode)

###############################################################################
def stripNamespace(tag):
###############################################################################
    """
    Remove a curly brace-encased namespace, if any.
    """
    match = reNamespace.match(tag)
    if match is None:
        strippedTag =  tag
    else:
        strippedTag = tag[len(match.group(0)):]

    return strippedTag


###############################################################################
class _gitRef():
###############################################################################
    """
    Class to enumerate git ref types
    """
    unknown      = 'unknown'
    localBranch  = 'localBranch'
    remoteBranch = 'remoteBranch'
    tag          = 'gitTag'
    sha1         = 'gitSHA1'

###############################################################################
class _repo(object):
###############################################################################
    """
    Class to represent and operate on a repository description.
    """
    def __init__(self, repo):
        """
        Parse repo (a <repo> XML element).
        """
        self._protocol = repo.get('protocol')
        self._tag = None
        self._branch = None
        self._URL = None
        for element in repo:
            ctag = stripNamespace(element.tag)
            if ctag == 'ROOT':
                self._URL  = element.text
            elif ctag == 'TAG':
                self._tag = element.text
            elif ctag == 'BRANCH':
                self._branch = element.text
            else:
                perr("Unknown repo element type, {}".format(element.tag))

        if self._URL is None:
            perr("repo must have a URL")

        if self._tag is None and self._branch is None:
            perr("repo must have either a BRANCH or a TAG element")

        if self._tag is not None and self._branch is not None:
            perr("repo cannot have both a BRANCH and a TAG element")

        if self._protocol is None:
            perr("repo must have a protocol")
        elif self._protocol == 'svn':
            if self._branch is not None:
                self._URL = os.path.join(self._URL, self._branch)
            else:
                self._URL = os.path.join(self._URL, self._tag)

        elif self._protocol == 'git':
            pass
        else:
            perr("Unknown repo protocol, {}".format(self._protocol))

    def load(self, repo_dir):
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the source.
        If the repo destination directory does not exist, checkout the correce
        branch or tag.
        """
        if self._protocol == 'svn':
            self.svnCheckout(repo_dir, self._URL)
        elif self._protocol == 'git':
            self.gitCheckout(repo_dir, self._URL, self._branch, self._tag)

        return True


    def svnCheckout(self, checkoutDir, repoURL):
        """
        Checkout a subversion repository (repoURL) to checkoutDir.
        """
        caller = "svnCheckout %s %s"%(checkoutDir, repoURL)
        retcode = scall(["svn", "checkout", repoURL, checkoutDir])
        quitOnFail(retcode, caller)


    def svnUpdate(self, updir):
        """
        Refresh a subversion sandbox (updir)
        """
        caller = "svnUpdate %s"%(updir)
        mycurrdir = os.path.abspath(".")
        os.chdir(updir)
        retcode = scall(["svn update"])
        quitOnFail(retcode, caller)
        os.chdir(mycurrdir)


    def svnCheckDir(self, chkdir, ver):
        """
        Check to see if directory (chkdir) exists and is the correct
        version (ver).
        Return True (correct), False (incorrect) or None (chkdir not found)

        """
        caller = "svnCheckDir %s %s"%(chkdir, ver)
        if os.path.exists(chkdir):
            svnout = checkOutput(["svn", "info", chkdir])
            if svnout is not None:
                url = None
                for line in svnout.splitlines():
                    if reUrlLine.match(line):
                        url = line.split(': ')[1]
                        break
                retVal = (url == ver)
            else:
                retVal = None
        else:
            retVal = None

        return retVal


    def gitRefType(self, ref):
        """
        Determine if 'ref' is a local branch, a remote branch, a tag, or a
        commit.
        Should probably use this command instead:
        git show-ref --verify --quiet refs/heads/<branch-name>
        """
        caller = "gitRefType %s"%(ref)
        refType = _gitRef.unknown
        # First check for local branch
        gitout = checkOutput(["git", "branch"])
        if gitout is not None:
            branches = [ x.lstrip('* ') for x in gitout.splitlines() ]
            for branch in branches:
                if branch == ref:
                    refType = _gitRef.localBranch
                    break

        # Next, check for remote branch
        if refType == _gitRef.unknown:
            gitout = checkOutput(["git", "branch", "-r"])
            if gitout is not None:
                for branch in gitout.splitlines():
                    match = reRemoteBranch.match(branch)
                    if (match is not None) and (match.group(1) == ref):
                        refType = _gitRef.remoteBranch
                        break

        # Next, check for a tag
        if refType == _gitRef.unknown:
            gitout = checkOutput(["git", "tag"])
            if gitout is not None:
                for tag in gitout.splitlines():
                    if tag == ref:
                        refType = _gitRef.tag
                        break

        # Finally, see if it just looks like a commit hash
        if (refType == _gitRef.unknown) and reGitHash.match(ref):
            refType = _gitRef.sha1

        # Return what we've come up with
        return refType


    def gitCurrentBranch(self):
        """
        Return the (current branch, sha1 hash) of working copy in wdir
        """
        caller = "gitCurrentBranch"
        branch = checkOutput(["git", "rev-parse", "--abbrev-ref", "HEAD"])
        hash = checkOutput(["git", "rev-parse", "HEAD"])
        if branch is not None:
            branch = branch.rstrip()

        if hash is not None:
            hash = hash.rstrip()

        return (branch, hash)

    def gitCheckDir(self, chkdir, ref):
        """
        Check to see if directory (chkdir) exists and is the correct
        treeish (ref)
        Return True (correct), False (incorrect) or None (chkdir not found)
        """
        caller = "gitCheckDir %s %s"%(chkdir, ref)
        refchk = None
        if os.path.exists(chkdir):
            if os.path.exists(os.path.join(chkdir, ".git")):
                mycurrdir = os.path.abspath(".")
                os.chdir(chkdir)
                head = checkOutput(["git", "rev-parse", "HEAD"])
                if ref is not None:
                    refchk = checkOutput(["git", "rev-parse", ref])

            else:
                head = None

            if ref is None:
                retVal = head is not None
            elif refchk is None:
                retVal = None
            else:
                retVal = (head == refchk)
        else:
            retVal = None

        os.chdir(mycurrdir)
        return retVal


    def gitWdirClean(self, wdir):
        """
        Return True if wdir is clean or False if there are modifications
        """
        caller = "getWdirClean %s"%(wdir)
        mycurrdir = os.path.abspath(".")
        os.chdir(wdir)
        retcode = retcall(["git", "diff", "--quiet", "--exit-code"])
        os.chdir(mycurrdir)
        return (retcode == 0)


    def gitRemote(self, repoDir):
        """
        Return the remote for the current branch or tag
        """
        caller = "gitRemote %s"%(repoDir)
        mycurrdir = os.path.abspath(".")
        os.chdir(repoDir)
        # Make sure we are on a remote-tracking branch
        (curr_branch, chash) = self.gitCurrentBranch()
        refType = self.gitRefType(curr_branch)
        if refType == _gitRef.remoteBranch:
            remote = checkOutput(["git", "config", "branch.{}.remote".format(cur_branch)])
        else:
            remote = None

        os.chdir(mycurrdir)
        return remote


    # Need to decide how to do this. Just doing pull for now
    def gitUpdate(self, repoDir):
        """
        Do an update and a FF merge if possible
        """
        caller = "gitUpdate %s"%(repoDir)
        mycurrdir = os.path.abspath(".")
        os.chdir(repoDir)
        remote = self.gitRemote(repoDir)
        if remote is not None:
            retcode = scall(["git", "remote", "update", "--prune", remote])
            quitOnFail(retcode, caller)

        retcode = scall(["git", "merge", "--ff-only", "@{u}"])
        os.chdir(mycurrdir)
        quitOnFail(retcode, caller)

    def gitCheckout(self, checkoutDir, repoURL, branch, tag):
        """
        Checkout 'branch' or 'tag' from 'repoURL'
        """
        caller = "gitCheckout %s %s"%(checkoutDir, repoURL)
        retcode = 0
        mycurrdir = os.path.abspath(".")
        if os.path.exists(checkoutDir):
            # We can't do a clone. See what we have here
            if self.gitCheckDir(checkoutDir, None):
                os.chdir(checkoutDir)
                # We have a git repo, is it from the correct URL?
                chkURL = checkOutput(["git", "config", "remote.origin.url"])
                if chkURL is not None:
                    chkURL = chkURL.rstrip()

                if chkURL != repoURL:
                    perr("Invalid repository in {0}, url = {1}, should be {2}".format(checkoutDir, chkURL, repoURL))

        else:
            print "Calling git clone %s %s"%(repoURL, checkoutDir)
            retcode = scall(["git", "clone", repoURL, checkoutDir])
            quitOnFail(retcode, caller)
            os.chdir(checkoutDir)

        if branch is not None:
            (curr_branch, chash) = self.gitCurrentBranch()
            refType = self.gitRefType(branch)
            if refType == _gitRef.remoteBranch:
                retcode = scall(["git", "checkout", "--track", "origin/"+branch])
                quitOnFail(retcode, caller)
            elif refType == _gitRef.localBranch:
                if curr_branch != branch:
                    if not self.gitWdirClean(checkoutDir):
                        perr("Working directory ({0}) not clean, aborting".format(checkoutDir))
                    else:
                        retcode = scall(["git", "checkout", ref])
                        quitOnFail(retcode, caller)

            else:
                perr("Unable to check out branch, {}".format(branch))

        elif tag is not None:
            # For now, do a hail mary and hope tag can be checked out
            retcode = scall(["git", "checkout", tag])
            quitOnFail(retcode, caller)

        os.chdir(mycurrdir)


###############################################################################
class _source(object):
###############################################################################
    """
    _source represents a <source> object in a <config_sourcetree>
    """
    def __init__(self, node):
        """
        Parse an XML node for a <source> tag
        """
        self._name = node.get('name')
        self._repos = list()
        self._loaded = False
        # Parse the sub-elements
        for child in node:
            ctag = stripNamespace(child.tag)
            if ctag == 'repo':
                self._repos.append(_repo(child))
            elif ctag == 'TREE_PATH':
                self._path = child.text
                self._repo_dir = os.path.basename(self._path)
            else:
                perr("Unknown source element type, {}".format(child.tag))
        if len(self._repos) == 0:
            perr("No repo element for source {}".format(name))


    def get_name(self):
        """
        Return the source object's name
        """
        return self._name

    def load(self, tree_root, all=False):
        """
        If the repo destination directory exists, ensure it is correct (from
        correct URL, correct branch or tag), and possibly update the source.
        If the repo destination directory does not exist, checkout the correce
        branch or tag.
        If all is True, also load all of the the sources sub-sources.
        """
        # Make sure we are in correct location
        ###################################
        mycurrdir = os.path.abspath(".")
        pdir = os.path.join(tree_root, os.path.dirname(self._path))
        if not os.path.exists(pdir):
            try:
                os.makedirs(pdir)
            except OSError as e:
                if e.errno != errno.EEXIST:
                    raise

        os.chdir(pdir)

        repoLoaded = self._loaded
        if not repoLoaded:
            for repo in self._repos:
                repoLoaded = repo.load(self._repo_dir)
                if repoLoaded:
                    break

        self._loaded = repoLoaded
        os.chdir(mycurrdir)
        return repoLoaded


## An object representing a source tree XML file
###############################################################################
class SourceTree(object):
###############################################################################
    """
    SourceTree represents a <config_sourcetree> object
    """
    def __init__(self, model_file, tree_root="."):
        """
        Parse a model file into a SourceTree object
        """
        self._tree_root = os.path.abspath(tree_root)

        file = open(model_file)
        self._tree = ET.parse(file)
        self._root = self._tree.getroot()
        file.close()

        self._all_components = {}
        self._required_compnames = []
        for child in self._root:
            if child.tag == "source":
                s = _source(child)
                self._all_components[s.get_name()] = s
            elif child.tag == "required":
                for req in child:
                    self._required_compnames.append(req.text)

    def load(self, all=False, load_comp=None):
        """
        Checkout or update indicated components into the the configured subdirs.
        If all is True, recursively checkout all sources.
        If all is False, load_comp is an optional set of components to load.
        If all is False and load_comp is None, only load the required sources.
        """
        if all:
            load_comps = self._all_components.keys()
        elif load_comp is not None:
            load_comps = [ load_comp ]
        else:
            load_comps = self._required_compnames

        if load_comps is not None:
            print "Loading these components: {}".format(load_comps)

        for comp in load_comps:
            self._all_components[comp].load(self._tree_root, all)


###############################################################################
def _main_func(command, args_in):
###############################################################################
    """
    Function to call when module is called from the command line.
    Parse model file and load required repositories or all repositories if
    the --all option is passed.
    """
    help_str = \
"""
{0} <MODEL.xml> [--all]
OR
{0} --help
""".format(os.path.basename(command))
    parser = argparse.ArgumentParser(usage=help_str)
    parser.add_argument("model", help="The model xml filename (e.g., CESM.xml).")
    parser.add_argument("--all",  action="store_true",
                        help="Load all components in model file (default only loads required components)")
    args = parser.parse_args(args=args_in)

    if not os.path.exists(args.model):
        print "ERROR: Model file, '{0}', does not exist".format(args.model)
        sys.exit(1)

    source_tree = SourceTree(args.model)
    source_tree.load(args.all)


###############################################################################
## Beginning of main program
###############################################################################
if __name__ == "__main__":
    _main_func(sys.argv[0], sys.argv[1:])
## End of main program
