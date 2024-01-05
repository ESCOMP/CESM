#!/usr/bin/env python
import sys
import os
import shutil
import logging
import argparse
from modules import utils
from configparser import ConfigParser
from modules.lstripreader import LstripReader
from modules.gitinterface import GitInterface

from contextlib import contextmanager


@contextmanager
def pushd(new_dir):
    previous_dir = os.getcwd()
    os.chdir(new_dir)
    try:
        yield
    finally:
        os.chdir(previous_dir)

def commandline_arguments(args=None):
    description = '''
    %(prog)s manages checking out groups of gitsubmodules with addtional support for Earth System Models
    '''
    parser = argparse.ArgumentParser(
        description=description, 
        formatter_class=argparse.RawDescriptionHelpFormatter)

    #
    # user options
    #
    parser.add_argument("components", nargs="*",
                        help="Specific component(s) to checkout. By default, "
                        "all required submodules are checked out.")

    parser.add_argument('-C', '--path', default=os.getcwd(),
                        help='Toplevel repository directory.  Defaults to current directory.')

    parser.add_argument('-x', '--exclude', nargs='*',
                        help='Component(s) listed in the gitmodules file which should be ignored.')

    parser.add_argument('-o', '--optional', action='store_true', default=False,
                        help='By default only the required submodules '
                        'are checked out. This flag will also checkout the '
                        'optional submodules relative to the toplevel directory.')

    parser.add_argument('-S', '--status', action='store_true', default=False,
                        help='Output the status of the repositories managed by '
                        '%(prog)s. By default only summary information '
                        'is provided. Use the verbose option to see details.')

    parser.add_argument('-u', '--update', action='store_true', default=False,
                        help='Update submodules to the tags defined in .gitmodules.')

    parser.add_argument('-v', '--verbose', action='count', default=0,
                        help='Output additional information to '
                        'the screen and log file. This flag can be '
                        'used up to two times, increasing the '
                        'verbosity level each time.')

    parser.add_argument('-V', '--version', action='store_true', default=False,
                        help='Print manage_externals version and exit.')

    #
    # developer options
    #
    parser.add_argument('--backtrace', action='store_true',
                        help='DEVELOPER: show exception backtraces as extra '
                        'debugging output')

    parser.add_argument('-d', '--debug', action='store_true', default=False,
                        help='DEVELOPER: output additional debugging '
                        'information to the screen and log file.')

    logging_group = parser.add_mutually_exclusive_group()

    logging_group.add_argument('--logging', dest='do_logging',
                               action='store_true',
                               help='DEVELOPER: enable logging.')
    logging_group.add_argument('--no-logging', dest='do_logging',
                               action='store_false', default=False,
                               help='DEVELOPER: disable logging '
                               '(this is the default)')
    if args:
        options = parser.parse_args(args)
    else:
        options = parser.parse_args()

    if options.optional:
        esmrequired = 'T:'
    else:
        esmrequired = 'T:T'
        
    if options.status:
        action = 'status'
    elif options.update:
        action = 'update'
    else:
        action = 'install'

    if options.version:
        version_info = ''
        version_file_path = os.path.join(os.path.dirname(__file__),'version.txt')
        with open(version_file_path) as f:
            version_info = f.readlines()[0].strip()
        print(version_info)
        sys.exit(0)


        
    return options.rootdir, esmrequired, options.components, options.exclude, options.verbose, action

        
def parse_submodules_desc_section(section, section_items):
    """Create a dict for this submodule description"""
    desc = {}
    esmrequired_options = ("T:T", "I:T", "I:F", "T:F")
    for item in section_items:
        name = item[0].strip().lower()
        desc[name] = item[1].strip()
        # e3sm needs to have ssh protocol urls, we don't
        if name == "url" and desc[name].startswith("git@github"):
            desc[name] = desc[name].replace("git@github.com:","https://github.com/")
    if not "esmrequired" in desc:
        desc["esmrequired"] = "I:T"
    
    if desc["esmrequired"] not in esmrequired_options:
        val = desc["esmrequired"]
        utils.fatal_error(f"esmrequired set to {val} which is not a supported option {esmrequired_options}")
    return desc


def submodule_sparse_checkout(name, url, path, sparsefile, tag="master"):
    # first create the module directory
    if not os.path.isdir(path):
        os.makedirs(path)
    # Check first if the module is already defined
    # and the sparse-checkout file exists
    git = GitInterface(os.getcwd())
    topdir = git.git_operation("rev-parse", "--show-toplevel").rstrip()

    topgit = os.path.join(topdir, ".git", "modules")
    gitsparse = os.path.join(topgit, name, "info","sparse-checkout")
    if os.path.isfile(gitsparse):
        logging.warning(f"submodule {name} is already initialized")
        return
    
    #initialize a new git repo and set the sparse checkout flag
    sprepo_git = GitInterface(os.path.join(topdir,path))
    sprepo_git.config_set_value("core", "sparseCheckout", "true")

    # set the repository remote
    cmd = ("remote", "add", "origin", url)
    sprepo_git.git_operation("remote", "add", "origin", url)
    
    if not os.path.isdir(topgit):
        os.makedirs(topgit)
    topgit = os.path.join(topgit,name)
    
    shutil.move(os.path.join(path, ".git"), topgit)

    shutil.copy(os.path.join(path,sparsefile), gitsparse)
        
    with open(os.path.join(path, ".git"), "w") as f:
        f.write("gitdir: " + os.path.relpath(topgit, path))

    #Finally checkout the repo
    sprepo_git.git_operation( "fetch", "--depth=1", "origin", "--tags")
    sprepo_git.git_operation( "checkout", tag)
    print(f"Successfully checked out {name}")

def submodule_checkout(root, name, url, path, tag, esmrequired):
    git = GitInterface(root)
    repodir = os.path.join(root, path)
    git.git_operation("submodule","update","--init", path)
    # Look for a .gitmodules file in the newly checkedout repo
    if os.path.exists(os.path.join(repodir,".gitmodules")):
        # recursively handle this checkout
        print(f"Recursively checking out submodules of {name} {repodir}")
        read_gitmodules_file(repodir, esmrequired)
    if os.path.exists(os.path.join(repodir,".git")):
        print(f"Successfully checked out {name}")
    else:
        utils.fatal_error(f"Failed to checkout {name}")
    return

def submodule_update(root_dir, url, tag):
    with pushd(root_dir):
        git = GitInterface(root_dir)
        # first make sure the url is correct
        upstream = git.git_operation("ls-remote","--git-url")
        if upstream != url:
            # TODO - this needs to be a unique name
            git.git_operation("remote","add","newbranch",url)
        git.git_operation("checkout", tag)


def read_gitmodules_file(root_dir, esmrequired, file_name=".gitmodules", gitmodulelist=None, action='install'):
    root_dir = os.path.abspath(root_dir)

    msg = 'In directory : {0}'.format(root_dir)
    logging.info(msg)

    file_path = os.path.join(root_dir, file_name)
    if not os.path.exists(file_path):
        msg = ('ERROR: submodules description file, "{0}", does not '
               'exist in dir:\n    {1}'.format(file_name, root_dir))
        utils.fatal_error(msg)
    config = ConfigParser()
    config.read_file(LstripReader(file_path), source=file_name)
    for section in config.sections():
        name = section[11:-1]
        submodule_desc = parse_submodules_desc_section(section,config.items(section))

        if action == 'install':
            # Recursively install submodules, honering esm tags in .gitmodules
            if submodule_desc["esmrequired"] not in esmrequired:
                if "T:F" in esmrequired or submodule_desc["esmrequired"].startswith("I:"):
                    print(f"Skipping optional component {section}")
                    # TODO change to logging
                    #                logging.info(f"Skipping optional component {section}")
                    continue
            if "esmtag" in submodule_desc:
                tag = submodule_desc["esmtag"]
            else:
                tag = "master"
            if "esmsparse" in submodule_desc:
                submodule_sparse_checkout(name, submodule_desc["url"], submodule_desc["path"],
                                          submodule_desc["esmsparse"], tag)
                continue
            Iesmrequired = []
            for setting in esmrequired:
                if setting.startswith("I:"):
                    Iesmrequired.append(setting) 
                submodule_checkout(root_dir, name, submodule_desc["url"], submodule_desc["path"], tag, Iesmrequired)

        if action == 'update':
            # update the submodules to the tags defined in .gitmodules
            if "esmtag" in submodule_desc:
                submod_dir = os.path.join(root_dir,submodule_desc['path'])
                if os.path.exists(os.path.join(submod_dir,".git")):
                    submodule_update(submod_dir, submodule_desc['url'], submodule_desc["esmtag"])

                
                

if __name__ == '__main__':
    root_dir, esmrequired, includelist, excludelist, verbose, action = commandline_arguments()
    esmrequired = ("I:T", "T:T")
    root_dir = os.getcwd()
    read_gitmodules_file(root_dir, esmrequired, gitmodulelist, action, verbose)
    
