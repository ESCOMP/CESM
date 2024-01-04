#!/usr/bin/env python
import os
import shutil
import logging
from modules import utils
from configparser import ConfigParser
from modules.lstripreader import LstripReader

def parse_submodules_desc_section(section, section_items):
    """Create a dict for this submodule description"""
    desc = {}
    esmrequired_options = ("T:T", "I:T", "I:F", "T:F")
    for item in section_items:
        name = item[0].strip().lower()
        desc[name] = item[1].strip()
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
    cmd = ("git", "rev-parse", "--show-toplevel")
    topdir = utils.execute_subprocess(cmd, output_to_caller=True).rstrip()
    topgit = os.path.join(topdir, ".git", "modules")
    gitsparse = os.path.join(topgit, name, "info","sparse-checkout")
    if os.path.isfile(gitsparse):
        logging.warning(f"submodule {name} is already initialized")
        return
    
    #initialize a new git repo and set the sparse checkout flag
    cmd = ("git", "-C", path, "init")
    status = utils.execute_subprocess(cmd, status_to_caller=True)
    cmd = ("git", "-C", path, "config", "core.sparseCheckout","true") 
    status = utils.execute_subprocess(cmd, status_to_caller=True)
    # set the repository remote
    cmd = ("git", "-C", path, "remote", "add", "origin", url) 
    status = utils.execute_subprocess(cmd, status_to_caller=True)
    
    if not os.path.isdir(topgit):
        os.makedirs(topgit)
    topgit = os.path.join(topgit,name)
    
    shutil.move(os.path.join(path, ".git"), topgit)

    shutil.copy(os.path.join(path,sparsefile), gitsparse)
        
    with open(os.path.join(path, ".git"), "w") as f:
        f.write("gitdir: " + os.path.relpath(topgit, path))

    #Finally checkout the repo
    cmd = ("git", "-C", path, "fetch", "--depth=1", "origin", "--tags")
    status = utils.execute_subprocess(cmd, status_to_caller=True)
    cmd = ("git", "-C", path, "checkout", tag)
    status = utils.execute_subprocess(cmd, status_to_caller=True)
    print(f"Successfully checked out {name}")
    
def read_gitmodules_file(root_dir, esmrequired, file_name=".gitmodules"):
    root_dir = os.path.abspath(root_dir)

    msg = 'In directory : {0}'.format(root_dir)
    logging.info(msg)

    file_path = os.path.join(root_dir, file_name)
    if not os.path.exists(file_name):
        msg = ('ERROR: submodules description file, "{0}", does not '
               'exist in dir:\n    {1}'.format(file_name, root_dir))
        utils.fatal_error(msg)
    config = ConfigParser()
    config.read_file(LstripReader(file_path), source=file_name)
    for section in config.sections():
        name = section[11:-1]
        submodule_desc = parse_submodules_desc_section(section,config.items(section))
        if submodule_desc["esmrequired"] not in esmrequired:
            if "T:F" in esmrequired or submodule_desc["esmrequired"].startswith("I:"):
                print(f"Skipping optional component {section}")
                # TODO change to logging
                #                logging.info(f"Skipping optional component {section}")
            continue
        if "esmsparse" in submodule_desc:
            if "esmtag" in submodule_desc:
                tag = submodule_desc["esmtag"]
            else:
                tag = "master"
            submodule_sparse_checkout(name, submodule_desc["url"], submodule_desc["path"],
                                      submodule_desc["esmsparse"], tag)





esmrequired = ("I:T", "T:T")
root_dir = os.getcwd()
gitmodules = read_gitmodules_file(root_dir, esmrequired)

    
