#!/usr/bin/env python

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

## Important paths
thisFile = os.path.realpath(inspect.getfile(inspect.currentframe()))
currDir = os.path.dirname(thisFile)

## Common regular expressions
reNamespace  = re.compile("{[^}]*}")
urlLine      = re.compile("^URL:")
gitHash      = re.compile("\A([a-fA-F0-9]+)\Z")
remoteBranch = re.compile("\s*origin/(\S+)")

##
## Error output function (should be handed a string)
##
def perr(errstr):
    print "{0}ERROR: {1}".format(os.linesep, errstr)
    exit(-1)

###
## Process execution helper functions -- don't really belong here
def checkOutput(commands):
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


def scall(commands):
    try:
        retcode = subprocess.check_call(commands)
    except OSError as e:
        print >>sys.stderr, "Execution of '{}' failed".format((' '.join(commands)))
        print >>sys.stderr,  e
        retcode = -1
    except ValueError as e:
        print >>sys.stderr, "ValueError in '{}'".format((' '.join(commands)))
        print >>sys.stderr,  e
        retcode = -1
    except subprocess.CalledProcessError as e:
        print >>sys.stderr, "CalledProcessError in '{}'".format((' '.join(commands)))
        print >>sys.stderr,  e
        retcode = -1

    return retcode


def retcall(commands):
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

    return retcode


def quitOnFail(retcode, caller):
    if retcode != 0:
        print >>sys.stderr, "%s failed with return code %d"%(caller, retcode)
        exit(retcode)

def stripNamespace(tag):
    match = reNamespace.match(tag)
    if match is None:
        strippedTag =  tag
    else:
        strippedTag = tag[len(match.group(0)):]

    return strippedTag


## Enumerate git ref types
class _gitRef():
    unknown      = 0
    localBranch  = 1
    remoteBranch = 2
    tag          = 3
    sha1         = 4

class _repo(object):
    def __init__(self, repo):
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
        if self._protocol == 'svn':
            self.svnCheckout(repo_dir, self._URL)
        elif self._protocol == 'git':
            self.gitCheckout(repo_dir, self._URL, self._branch, self._tag)

        return True


    def svnCheckout(self, checkoutDir, repoURL):
        caller = "svnCheckout %s %s"%(checkoutDir, repoURL)
        retcode = scall(["svn", "checkout", repoURL, checkoutDir])
        quitOnFail(retcode, caller)


    def svnUpdate(self, updir):
        caller = "svnUpdate %s"%(updir)
        mycurrdir = os.path.abspath(".")
        os.chdir(updir)
        retcode = scall(["svn update"])
        quitOnFail(retcode, caller)
        os.chdir(mycurrdir)


    # Check to see if directory (chkdir) exists and is the correct version (ver)
    # returns True (correct), False (incorrect) or None (chkdir not found)
    def svnCheckDir(self, chkdir, ver):
        caller = "svnCheckDir %s %s"%(chkdir, ver)
        if os.path.exists(chkdir):
            svnout = checkOutput(["svn", "info", chkdir])
            if svnout is not None:
                url = None
                for line in svnout.splitlines():
                    if urlLine.match(line):
                        url = line.split(': ')[1]
                        break
                retVal = (url == ver)
            else:
                retVal = None
        else:
            retVal = None

        return retVal


    # Determine if 'ref' is a local branch, a remote branch, a tag, or a commit
    # Should probably use this command instead
    #git show-ref --verify --quiet refs/heads/<branch-name>
    def gitRefType(self, ref):
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
                    match = remoteBranch.match(branch)
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
        if (refType == _gitRef.unknown) and gitHash.match(ref):
            refType = _gitRef.sha1

        # Return what we've come up with
        return refType


    # Return the (current branch, sha1 hash) of working copy in wdir
    def gitCurrentBranch(self, wdir):
        caller = "gitCurrentBranch {}".format(wdir)
        mycurrdir = os.path.abspath(".")
        os.chdir(wdir)
        branch = checkOutput(["git", "rev-parse", "--abbrev-ref", "HEAD"])
        hash = checkOutput(["git", "rev-parse", "HEAD"])
        if branch is not None:
            branch = branch.rstrip()

        if hash is not None:
            hash = hash.rstrip()

        os.chdir(mycurrdir)
        return (branch, hash)


    # Check to see if directory (chkdir) exists and is the correct version (ver)
    # returns True (correct), False (incorrect) or None (chkdir not found)
    def gitCheckDir(self, chkdir, ref):
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
        caller = "getWdirClean %s"%(wdir)
        mycurrdir = os.path.abspath(".")
        os.chdir(wdir)
        retcode = retcall(["git", "diff", "--quiet", "--exit-code"])
        os.chdir(mycurrdir)
        return (retcode == 0)


    # Need to decide how to do this. Just doing pull for now
    def gitUpdate(self, repoDir):
        caller = "gitUpdate %s"%(repoDir)
        mycurrdir = os.path.abspath(".")
        os.chdir(repoDir)
        retcode = scall(["git", "pull"])
        os.chdir(mycurrdir)
        quitOnFail(retcode, caller)


    def gitCheckout(self, checkoutDir, repoURL, branch, tag):
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
                    perr("Invalid repository in {0}, url = {0}, should be {1}".format(checkoutDir, chkURL, repoURL))

        else:
            print "Calling git clone %s %s"%(repoURL, checkoutDir)
            retcode = scall(["git", "clone", repoURL, checkoutDir])
            quitOnFail(retcode, caller)
            os.chdir(checkoutDir)

        if branch is not None:
            (curr_branch, chash) = gitCurrentBranch(checkoutDir)
            refType = gitRefType(branch)
            if refType == _gitRef.remoteBranch:
                retcode = scall(["git", "checkout", "--track", "origin/"+ref])
                quitOnFail(retcode, caller)
            elif refType == _gitRef.localBranch:
                if curr_branch != branch:
                    if not gitWdirClean(checkoutDir):
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


class _source(object):
    def __init__(self, node):
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
        return self._name

    def load(self, tree_root):
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
class SourceTree(object):
    def __init__(self, model_file, tree_root="."):
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

    def load(self, all=False):
        if all:
            load_comps = self._all_components.keys()
        else:
            load_comps = self._required_compnames

        if load_comps is not None:
            print "Loading these components: {}".format(load_comps)

        for comp in load_comps:
            self._all_components[comp].load(self._tree_root)


def _main_func(command, args_in):
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


## Beginning of main program
if __name__ == "__main__":
    _main_func(sys.argv[0], sys.argv[1:])
## End of main program
