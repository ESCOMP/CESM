#!/usr/bin/env python
import sys

MIN_PYTHON = (3, 7)
if sys.version_info < MIN_PYTHON:
    sys.exit("Python %s.%s or later is required." % MIN_PYTHON)

import os
import shutil
import logging
import textwrap
from git_fleximod import utils
from git_fleximod import cli
from git_fleximod.gitinterface import GitInterface
from git_fleximod.gitmodules import GitModules
from git_fleximod.submodule import Submodule

# logger variable is global
logger = None


def fxrequired_allowed_values():
    return ["ToplevelRequired", "ToplevelOptional", "AlwaysRequired", "AlwaysOptional", "TopLevelRequired", "TopLevelOptional"]


def commandline_arguments(args=None):
    parser = cli.get_parser()

    if args:
        options = parser.parse_args(args)
    else:
        options = parser.parse_args()

    # explicitly listing a component overrides the optional flag
    if options.optional or options.components:
        fxrequired = fxrequired_allowed_values()
    else:
        fxrequired = ["ToplevelRequired", "AlwaysRequired", "TopLevelRequired"]

    action = options.action
    if not action:
        action = "update"
    handlers = [logging.StreamHandler()]

    if options.debug:
        try:
            open("fleximod.log", "w")
        except PermissionError:
            sys.exit("ABORT: Could not write file fleximod.log")
        level = logging.DEBUG
        handlers.append(logging.FileHandler("fleximod.log"))
    elif options.verbose:
        level = logging.INFO
    else:
        level = logging.WARNING
    # Configure the root logger
    logging.basicConfig(
        level=level, format="%(name)s - %(levelname)s - %(message)s", handlers=handlers
    )

    if hasattr(options, "version"):
        exit()

    return (
        options.path,
        options.gitmodules,
        fxrequired,
        options.components,
        options.exclude,
        options.force,
        action,
    )


def submodule_sparse_checkout(root_dir, name, url, path, sparsefile, tag="master"):
    """
    This function performs a sparse checkout of a git submodule.  It does so by first creating the .git/info/sparse-checkout fileq
    in the submodule and then checking out the desired tag.  If the submodule is already checked out, it will not be checked out again.
    Creating the sparse-checkout file first prevents the entire submodule from being checked out and then removed.  This is important
    because the submodule may have a large number of files and checking out the entire submodule and then removing it would be time
    and disk space consuming.

    Parameters:
    root_dir (str): The root directory for the git operation.
    name (str): The name of the submodule.
    url (str): The URL of the submodule.
    path (str): The path to the submodule.
    sparsefile (str): The sparse file for the submodule.
    tag (str, optional): The tag to checkout. Defaults to "master".

    Returns:
    None
    """
    logger.info("Called sparse_checkout for {}".format(name))
    rgit = GitInterface(root_dir, logger)
    superroot = git_toplevelroot(root_dir, logger)

    if superroot:
        gitroot = superroot.strip()
    else:
        gitroot = root_dir.strip()
    assert os.path.isdir(os.path.join(gitroot, ".git"))
    # first create the module directory
    if not os.path.isdir(os.path.join(root_dir, path)):
        os.makedirs(os.path.join(root_dir, path))

    # initialize a new git repo and set the sparse checkout flag
    sprep_repo = os.path.join(root_dir, path)
    sprepo_git = GitInterface(sprep_repo, logger)
    if os.path.exists(os.path.join(sprep_repo, ".git")):
        try:
            logger.info("Submodule {} found".format(name))
            chk = sprepo_git.config_get_value("core", "sparseCheckout")
            if chk == "true":
                logger.info("Sparse submodule {} already checked out".format(name))
                return
        except NoOptionError:
            logger.debug("Sparse submodule {} not present".format(name))
        except Exception as e:
            utils.fatal_error("Unexpected error {} occured.".format(e))

    sprepo_git.config_set_value("core", "sparseCheckout", "true")

    # set the repository remote

    logger.info("Setting remote origin in {}/{}".format(root_dir, path))
    _, remotelist = sprepo_git.git_operation("remote", "-v")
    if url not in remotelist:
        sprepo_git.git_operation("remote", "add", "origin", url)

    topgit = os.path.join(gitroot, ".git")

    if gitroot != root_dir and os.path.isfile(os.path.join(root_dir, ".git")):
        with open(os.path.join(root_dir, ".git")) as f:
            gitpath = os.path.relpath(
                os.path.join(root_dir, f.read().split()[1]),
                start=os.path.join(root_dir, path),
            )
        topgit = os.path.join(gitpath, "modules")
    else:
        topgit = os.path.relpath(
            os.path.join(root_dir, ".git", "modules"),
            start=os.path.join(root_dir, path),
        )

    with utils.pushd(sprep_repo):
        if not os.path.isdir(topgit):
            os.makedirs(topgit)
    topgit += os.sep + name

    if os.path.isdir(os.path.join(root_dir, path, ".git")):
        with utils.pushd(sprep_repo):
            if os.path.isdir(os.path.join(topgit,".git")):
                shutil.rmtree(os.path.join(topgit,".git"))
            shutil.move(".git", topgit)
            with open(".git", "w") as f:
                f.write("gitdir: " + os.path.relpath(topgit))
            #    assert(os.path.isdir(os.path.relpath(topgit, start=sprep_repo)))
            gitsparse = os.path.abspath(os.path.join(topgit, "info", "sparse-checkout"))
        if os.path.isfile(gitsparse):
            logger.warning(
                "submodule {} is already initialized {}".format(name, topgit)
            )
            return

        with utils.pushd(sprep_repo):
            if os.path.isfile(sparsefile):
                shutil.copy(sparsefile, gitsparse)
                

    # Finally checkout the repo
    sprepo_git.git_operation("fetch", "origin", "--tags")
    sprepo_git.git_operation("checkout", tag)

    print(f"Successfully checked out {name:>20} at {tag}")
    rgit.config_set_value(f'submodule "{name}"', "active", "true")
    rgit.config_set_value(f'submodule "{name}"', "url", url)

def init_submodule_from_gitmodules(gitmodules, name, root_dir, logger):
    path = gitmodules.get(name, "path")
    url = gitmodules.get(name, "url")
    assert path and url, f"Malformed .gitmodules file {path} {url}"
    tag = gitmodules.get(name, "fxtag")
    fxurl = gitmodules.get(name, "fxDONOTUSEurl")
    fxsparse = gitmodules.get(name, "fxsparse")
    fxrequired = gitmodules.get(name, "fxrequired")
    return Submodule(root_dir, name, path, url, fxtag=tag, fxurl=fxurl, fxsparse=fxsparse, fxrequired=fxrequired, logger=logger)

def submodules_status(gitmodules, root_dir, toplevel=False, depth=0):
    testfails = 0
    localmods = 0
    needsupdate = 0
    wrapper = textwrap.TextWrapper(initial_indent=' '*(depth*10), width=120,subsequent_indent=' '*(depth*20))
    for name in gitmodules.sections():
        submod = init_submodule_from_gitmodules(gitmodules, name, root_dir, logger)
            
        result,n,l,t = submod.status()
        if toplevel or not submod.toplevel():
            print(wrapper.fill(result))
            testfails += t
            localmods += l
            needsupdate += n
        subdir = os.path.join(root_dir, submod.path)
        if os.path.exists(os.path.join(subdir, ".gitmodules")):
            gsubmod = GitModules(logger, confpath=subdir)
            t,l,n = submodules_status(gsubmod, subdir, depth=depth+1)
            if toplevel or not submod.toplevel():
                testfails += t
                localmods += l
                needsupdate += n
            
    return testfails, localmods, needsupdate

def git_toplevelroot(root_dir, logger):
    rgit = GitInterface(root_dir, logger)
    _, superroot = rgit.git_operation("rev-parse", "--show-superproject-working-tree")
    return superroot

def submodules_update(gitmodules, root_dir, requiredlist, force):
    for name in gitmodules.sections():
        submod = init_submodule_from_gitmodules(gitmodules, name, root_dir, logger)
    
        _, needsupdate, localmods, testfails = submod.status()
        if not submod.fxrequired:
            submod.fxrequired = "AlwaysRequired"
        fxrequired = submod.fxrequired    
        allowedvalues = fxrequired_allowed_values()
        assert fxrequired in allowedvalues

        superroot = git_toplevelroot(root_dir, logger)
                                     
        if (
            fxrequired
            and ((superroot and "Toplevel" in fxrequired)
            or fxrequired not in requiredlist)
        ):
            if "Optional" in fxrequired and "Optional" not in requiredlist:
                if fxrequired.startswith("Always"):
                    print(f"Skipping optional component {name:>20}")
                continue
        optional = "AlwaysOptional" in requiredlist

        if fxrequired in requiredlist:
            submod.update()
            repodir = os.path.join(root_dir, submod.path)
            if os.path.exists(os.path.join(repodir, ".gitmodules")):
                # recursively handle this checkout
                print(f"Recursively checking out submodules of {name}")
                gitsubmodules = GitModules(submod.logger, confpath=repodir)
                newrequiredlist = ["AlwaysRequired"]
                if optional:
                    newrequiredlist.append("AlwaysOptional")

                submodules_update(gitsubmodules, repodir, newrequiredlist, force=force)

def local_mods_output():
    text = """\
    The submodules labeled with 'M' above are not in a clean state.
    The following are options for how to proceed:
    (1) Go into each submodule which is not in a clean state and issue a 'git status'
        Either revert or commit your changes so that the submodule is in a clean state.
    (2) use the --force option to git-fleximod
    (3) you can name the particular submodules to update using the git-fleximod command line
    (4) As a last resort you can remove the submodule (via 'rm -fr [directory]')
        then rerun git-fleximod update.
"""
    print(text)

def submodules_test(gitmodules, root_dir):
    """
    This function tests the git submodules based on the provided parameters.

    It first checks that fxtags are present and in sync with submodule hashes.
    Then it ensures that urls are consistent with fxurls (not forks and not ssh)
    and that sparse checkout files exist.

    Parameters:
    gitmodules (ConfigParser): The gitmodules configuration.
    root_dir (str): The root directory for the git operation.

    Returns:
    int: The number of test failures.
    """
    # First check that fxtags are present and in sync with submodule hashes
    testfails, localmods, needsupdate = submodules_status(gitmodules, root_dir)
    print("")
    # Then make sure that urls are consistant with fxurls (not forks and not ssh)
    # and that sparse checkout files exist
    for name in gitmodules.sections():
        url = gitmodules.get(name, "url")
        fxurl = gitmodules.get(name, "fxDONOTUSEurl")
        fxsparse = gitmodules.get(name, "fxsparse")
        path = gitmodules.get(name, "path")
        fxurl = fxurl[:-4] if fxurl.endswith(".git") else fxurl
        url = url[:-4] if url.endswith(".git") else url
        if not fxurl or url.lower() != fxurl.lower():
            print(f"{name:>20} url {url} not in sync with required {fxurl}")
            testfails += 1
        if fxsparse and not os.path.isfile(os.path.join(root_dir, path, fxsparse)):
            print(f"{name:>20} sparse checkout file {fxsparse} not found")
            testfails += 1
    return testfails + localmods + needsupdate


def main():
    (
        root_dir,
        file_name,
        fxrequired,
        includelist,
        excludelist,
        force,
        action,
    ) = commandline_arguments()
    # Get a logger for the package
    global logger
    logger = logging.getLogger(__name__)

    logger.info("action is {} root_dir={} file_name={}".format(action, root_dir, file_name))
    
    if not root_dir or not os.path.isfile(os.path.join(root_dir, file_name)):
        if root_dir:
            file_path = utils.find_upwards(root_dir, file_name)

        if root_dir is None or file_path is None:
            root_dir = "."
            utils.fatal_error(
                "No {} found in {} or any of it's parents".format(file_name, root_dir)
            )

        root_dir = os.path.dirname(file_path)
    logger.info(
        "root_dir is {} includelist={} excludelist={}".format(
            root_dir, includelist, excludelist
        )
    )
    gitmodules = GitModules(
        logger,
        confpath=root_dir,
        conffile=file_name,
        includelist=includelist,
        excludelist=excludelist,
    )
    if not gitmodules.sections():
        sys.exit(f"No submodule components found, root_dir={root_dir}")
    retval = 0
    if action == "update":
        submodules_update(gitmodules, root_dir, fxrequired, force)
    elif action == "status":
        tfails, lmods, updates = submodules_status(gitmodules, root_dir, toplevel=True)
        if tfails + lmods + updates > 0:
            print(
                f"    testfails = {tfails}, local mods = {lmods}, needs updates {updates}\n"
            )
            if lmods > 0:
                local_mods_output()
    elif action == "test":
        retval = submodules_test(gitmodules, root_dir)
    else:
        utils.fatal_error(f"unrecognized action request {action}")
    return retval


if __name__ == "__main__":
    sys.exit(main())
