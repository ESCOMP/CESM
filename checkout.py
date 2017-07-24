#!/usr/bin/env python

import sys
import os
import os.path
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

## Enumerate git ref types
class gitRef():
  unknown      = 0
  localBranch  = 1
  remoteBranch = 2
  tag          = 3
  sha1         = 4
# End class gitRef

##
## General syntax help function
## Usage: help <exit status>
##
def help (errcode=0):
  hname="Usage: %s"%os.path.basename(thisFile)
#  hprefix="`echo ${hname} | tr '[!-~]' ' '`"
  print "%s [ <checkout directories file> ]"%hname
  exit(errcode)
#End help

##
## Error output function (should be handed a string)
##
def perr(errstr):
  print "%sERROR: %s"%(os.linesep, errstr)
  help(1)
# End perr

def checkOutput(commands):
  try:
    outstr = subprocess.check_output(commands)
  except OSError as e:
    print >>sys.stderr, "Execution of '%s' failed:"%(' '.join(commands)), e
  except ValueError as e:
    print >>sys.stderr, "ValueError in '%s':"%(' '.join(commands)), e
    outstr = None
  except subprocess.CalledProcessError as e:
    print >>sys.stderr, "CalledProcessError in '%s':"%(' '.join(commands)), e
    outstr = None
  # End of try
  return outstr
# End of checkOutput

def scall(commands):
  try:
    retcode = subprocess.check_call(commands)
  except OSError as e:
    print >>sys.stderr, "Execution of '%s' failed"%(' '.join(commands))
    print >>sys.stderr,  e
    retcode = -1
  except ValueError as e:
    print >>sys.stderr, "ValueError in '%s'"%(' '.join(commands))
    print >>sys.stderr,  e
    retcode = -1
  except subprocess.CalledProcessError as e:
    print >>sys.stderr, "CalledProcessError in '%s'"%(' '.join(commands))
    print >>sys.stderr,  e
    retcode = -1
  # End of try
  return retcode
# End of scall

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
  # End of try
  return retcode
# End of retcall

def quitOnFail(retcode, caller):
  if retcode != 0:
    print >>sys.stderr, "%s failed with return code %d"%(caller, retcode)
    exit(retcode)
  # End if
# End quitOnFail

def svnCheckout(checkoutDir, repoURL):
  caller = "svnCheckout %s %s"%(checkoutDir, repoURL)
  retcode = scall(["svn", "checkout", repoURL, checkoutDir])
  quitOnFail(retcode, caller)
# End svnCheckout

def svnUpdate(updir):
  caller = "svnUpdate %s"%(updir)
  mycurrdir = os.path.abspath(".")
  os.chdir(updir)
  retcode = scall(["svn update"])
  quitOnFail(retcode, caller)
  os.chdir(mycurrdir)
# End svnUpdate

# Check to see if directory (chkdir) exists and is the correct version (ver)
# returns True (correct), False (incorrect) or None (chkdir not found)
def svnCheckDir(chkdir, ver):
  caller = "svnCheckDir %s %s"%(chkdir, ver)
  if os.path.exists(chkdir):
    svnout = checkOutput(["svn", "info", chkdir])
    if svnout is not None:
      url = None
      for line in svnout.splitlines():
        if urlLine.match(line):
          url = line.split(': ')[1]
          break
        # End if
      # End for
      retVal = (url == ver)
    else:
      retVal = None
    # End if
  else:
    retVal = None
  # End if
  return retVal
# End svnCheckDir

# Determine if 'ref' is a local branch, a remote branch, a tag, or a commit
# Should probably use this command instead
#git show-ref --verify --quiet refs/heads/<branch-name>
def gitRefType(ref):
  caller = "gitRefType %s"%(ref)
  refType = gitRef.unknown
  # First check for local branch
  gitout = checkOutput(["git", "branch"])
  if gitout is not None:
    branches = [ x.lstrip('* ') for x in gitout.splitlines() ]
    for branch in branches:
      if branch == ref:
        refType = gitRef.localBranch
        break
      # End if
    # End for
  # End if
  # Next, check for remote branch
  if refType == gitRef.unknown:
    gitout = checkOutput(["git", "branch", "-r"])
    if gitout is not None:
      for branch in gitout.splitlines():
        match = remoteBranch.match(branch)
        if (match is not None) and (match.group(1) == ref):
          refType = gitRef.remoteBranch
          break
        # End if
      # End for
    # End if
  # End if
  # Next, check for a tag
  if refType == gitRef.unknown:
    gitout = checkOutput(["git", "tag"])
    if gitout is not None:
      for tag in gitout.splitlines():
        if tag == ref:
          refType = gitRef.tag
          break
        # End if
      # End for
    # End if
  # End if
  # Finally, see if it just looks like a commit hash
  if (refType == gitRef.unknown) and gitHash.match(ref):
    refType = gitRef.sha1
  # End if

  # Return what we've come up with
  return refType
# End gitRefType

# Return the (current branch, sha1 hash) of working copy in wdir
def gitCurrentBranch(wdir):
  caller = "gitCurrentBranch %s"%(wdir)
  branch = checkOutput(["git", "-C", wdir, "rev-parse", "--abbrev-ref", "HEAD"])
  hash = checkOutput(["git", "-C", wdir, "rev-parse", "HEAD"])
  if branch is not None:
    branch = branch.rstrip()
  # End if
  if hash is not None:
    hash = hash.rstrip()
  # End if
  return (branch, hash)
# End gitCurrentBranch

# Check to see if directory (chkdir) exists and is the correct version (ver)
# returns True (correct), False (incorrect) or None (chkdir not found)
def gitCheckDir(chkdir, ref):
  caller = "gitCheckDir %s %s"%(chkdir, ref)
  if os.path.exists(chkdir):
    if os.path.exists(os.path.join(chkdir, ".git")):
      head = checkOutput(["git", "-C", chkdir, "rev-parse", "HEAD"])
    else:
      head = None
    # End if
    if ref is None:
      refchk = None
    else:
      refchk = checkOutput(["git", "-C", chkdir, "rev-parse", ref])
    # End if
    if ref is None:
      retVal = head is not None
    elif refchk is None:
      retVal = None
    else:
      retVal = (head == refchk)
    # End if
  else:
    retVal = None
  # End if
  return retVal
# End gitCheckDir

def gitWdirClean(wdir):
  caller = "getWdirClean %s"%(wdir)
  gitcmd = ["git", "-C", wdir]
  retcode = retcall(gitcmd + ["diff", "--quiet", "--exit-code"])
  return (retcode == 0)
# End def gitWdirClean

# Need to decide how to do this. Just doing pull for now
def gitUpdate(repoDir):
  caller = "gitUpdate %s"%(repoDir)
  retcode = scall(["git", "-C", repoDir, "pull"])
  quitOnFail(retcode, caller)
# End gitUpdate

def gitCheckout(checkoutDir, repoURL, ref=None):
  caller = "gitCheckout %s %s"%(checkoutDir, repoURL)
  gitcmd = ["git", "-C", checkoutDir]
  retcode = 0
  if os.path.exists(checkoutDir):
    # We can't do a clone. See what we have here
    if gitCheckDir(checkoutDir, None):
      # We have a git repo, is it from the correct URL?
      chkURL = checkOutput(gitcmd + ["config", "remote.origin.url"])
      print chkURL
      if chkURL is not None:
        chkURL = chkURL.rstrip()
      # End if
      if chkURL != repoURL:
        print >>sys.stderr, "Invalid repository in %s"%(checkoutDir)
        print >>sys.stderr, "url = %s, should be %s"%(chkURL, repoURL)
        exit(-1)
      # End if
    # End if
  else:
    print "Calling git clone %s %s"%(repoURL, checkoutDir)
    retcode = scall(["git", "clone", repoURL, checkoutDir])
    quitOnFail(retcode, caller)
  # End if

  if ref is not None:
    (branch, chash) = gitCurrentBranch(checkoutDir)
    refType = gitRefType(ref)
    if refType == gitRef.remoteBranch:
      retcode = scall(gitcmd + ["checkout", "--track", "origin/"+ref])
    elif refType == gitRef.localBranch:
      if branch != ref:
        if not gitWdirClean(checkoutDir):
          print >>sys.stderr, "Working directory (%s) not clean, aborting"%(checkoutDir)
          exit(-1)
        else:
          retcode = scall(gitcmd + ["checkout", ref])
        # End if
    else:
      # For now, do a hail mary and hope ref can be checked out
      retcode = scall(gitcmd + ["checkout", ref])
    # End if
    quitOnFail(retcode, caller)
  # End if
# End gitCheckout

def stripNamespace(tag):
  match = reNamespace.match(tag)
  if match is None:
    strippedTag =  tag
  else:
    strippedTag = tag[len(match.group(0)):]
  # End if
  return strippedTag
# End stripNamespace

def printElement(element, prefix = None):
  if prefix is None:
    print element.tag, element.attrib
  else:
    print prefix, element.tag, element.attrib
  # End if
# End printElement

def getSourceRepos(element):
  repos = list()
  for child in element:
    ctag = stripNamespace(child.tag)
    if ctag == 'repo':
      repos.append(child)
    else:
      perr("Unknown source child type, %s"%child.tag)
    # End if
  # End for
  return repos
# End getSourceRepos

def handleSource(element, treeRoot):
  # Make sure we are in correct location
  ###################################
  name = element.get('name')
  print "source %s found"%name
  repoLoc = element.get('tree_path')
  repos = getSourceRepos(element)
  if len(repos) == 0:
    perr("No repo element for source %s"%name)
  else:
    repoLoaded = False
    while not repoLoaded:
      repo = repos.pop(0)
      protocol = repo.get('protocol')
      repoURL  = repo.get('root')
      repoRef = repo.get('ref')
      print "    repo protocol is %s"%protocol
      print "    repo url is %s"%repoURL
      if repoRef is not None:
        print "    repo ref is %s"%repoRef
      # End if
      if (protocol == 'svn'):
        svnCheckout(repoLoc, repoURL)
      elif (protocol == 'git'):
        gitCheckout(repoLoc, repoURL, repoRef)
      # End if
      if (len(repos) == 0) and (not repoLoaded):
        ##XXgoldyXX: This should be an error
        repoLoaded = True
      # End if
    # End while
  # End if
# End handleSource

def handleStaging(element, treeRoot):
  perr("handleStaging not implemented")
# End handleStaging

## Beginning of main program
if __name__ == "__main__":
    help_str = \
"""
{0} <MODEL.xml> [--all]
OR
{0} --help
""".format(os.path.basename(sys.argv[0]))
    parser = argparse.ArgumentParser(usage=help_str)
    parser.add_argument("model", help="The model xml filename (e.g., CESM.xml).")
    parser.add_argument("--all", default=False,
                        help="Load all components in model file (default only loads required components)")
    args = parser.parse_args()

    if not os.path.exists(args.model):
        print "ERROR: Model file, '{0}', does not exist".format(args.model)
        sys.exit(1)

    treeRoot = "CESM"

    file = open(args.model)
    tree = ET.parse(file)
    root = tree.getroot()
    file.close()

    all_components = []
    required_components = []
    for child in root:
        if child.tag == "source":
            all_components.append(child)
        elif child.tag == "required":
            for req in child:
                required_components.append(req.text)

    print [ x.get('name') for x in all_components ]
    print required_components
        # # Fix this
        # pos = child.tag.index('}') + 1
        # tagname = child.tag[pos:]
        # if tagname == 'source':
        #     handleSource(child, treeRoot)
        # elif tagname == 'staging':
        #     handleStaging(child, treeRoot)
        # else:
        #     print 'ERROR: Unknown element, %s'%tagname
        #     exit(1)

## End of main program
