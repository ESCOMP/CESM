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
from configparser import NoOptionError

# logger variable is global
logger = None


def fxrequired_allowed_values():
    return ["ToplevelRequired", "ToplevelOptional", "AlwaysRequired", "AlwaysOptional"]


def commandline_arguments(args=None):
    parser = cli.get_parser()

    if args:
        options = parser.parse_args(args)
    else:
        options = parser.parse_args()

    # explicitly listing a component overrides the optional flag
    if options.optional or options.components:
        fxrequired = [
            "ToplevelRequired",
            "ToplevelOptional",
            "AlwaysRequired",
            "AlwaysOptional",
        ]
    else:
        fxrequired = ["ToplevelRequired", "AlwaysRequired"]

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
    superroot = rgit.git_operation("rev-parse", "--show-superproject-working-tree")
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
    status = sprepo_git.git_operation("remote", "-v")
    if url not in status:
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
            shutil.copy(sparsefile, gitsparse)

    # Finally checkout the repo
    sprepo_git.git_operation("fetch", "origin", "--tags")
    sprepo_git.git_operation("checkout", tag)

    print(f"Successfully checked out {name:>20} at {tag}")
    rgit.config_set_value(f'submodule "{name}"', "active", "true")
    rgit.config_set_value(f'submodule "{name}"', "url", url)


def single_submodule_checkout(
    root, name, path, url=None, tag=None, force=False, optional=False
):
    """
    This function checks out a single git submodule.

    Parameters:
    root (str): The root directory for the git operation.
    name (str): The name of the submodule.
    path (str): The path to the submodule.
    url (str, optional): The URL of the submodule. Defaults to None.
    tag (str, optional): The tag to checkout. Defaults to None.
    force (bool, optional): If set to True, forces the checkout operation. Defaults to False.
    optional (bool, optional): If set to True, the submodule is considered optional. Defaults to False.

    Returns:
    None
    """
    # function implementation...
    git = GitInterface(root, logger)
    repodir = os.path.join(root, path)
    logger.info("Checkout {} into {}/{}".format(name, root, path))
    # if url is provided update to the new url
    tmpurl = None
    repo_exists = False
    if os.path.exists(os.path.join(repodir, ".git")):
        logger.info("Submodule {} already checked out".format(name))
        repo_exists = True
    # Look for a .gitmodules file in the newly checkedout repo
    if not repo_exists and url:
        # ssh urls cause problems for those who dont have git accounts with ssh keys defined
        # but cime has one since e3sm prefers ssh to https, because the .gitmodules file was
        # opened with a GitModules object we don't need to worry about restoring the file here
        # it will be done by the GitModules class
        if url.startswith("git@"):
            tmpurl = url
            url = url.replace("git@github.com:", "https://github.com/")
            git.git_operation("clone", url, path)
            smgit = GitInterface(repodir, logger)
            if not tag:
                tag = smgit.git_operation("describe", "--tags", "--always").rstrip()
            smgit.git_operation("checkout", tag)
            # Now need to move the .git dir to the submodule location
            rootdotgit = os.path.join(root, ".git")
            if os.path.isfile(rootdotgit):
                with open(rootdotgit) as f:
                    line = f.readline()
                    if line.startswith("gitdir: "):
                        rootdotgit = line[8:].rstrip()

            newpath = os.path.abspath(os.path.join(root, rootdotgit, "modules", name))
            if os.path.exists(newpath):
                shutil.rmtree(os.path.join(repodir, ".git"))
            else:
                shutil.move(os.path.join(repodir, ".git"), newpath)

            with open(os.path.join(repodir, ".git"), "w") as f:
                f.write("gitdir: " + os.path.relpath(newpath, start=repodir))
                
    if not os.path.exists(repodir):
        parent = os.path.dirname(repodir)
        if not os.path.isdir(parent):
            os.makedirs(parent)
        git.git_operation("submodule", "add", "--name", name, "--", url, path) 

    if not repo_exists or not tmpurl:
        git.git_operation("submodule", "update", "--init", "--", path)
            
    if os.path.exists(os.path.join(repodir, ".gitmodules")):
        # recursively handle this checkout
        print(f"Recursively checking out submodules of {name}")
        gitmodules = GitModules(logger, confpath=repodir)
        requiredlist = ["AlwaysRequired"]
        if optional:
            requiredlist.append("AlwaysOptional")
        submodules_checkout(gitmodules, repodir, requiredlist, force=force)
    if not os.path.exists(os.path.join(repodir, ".git")):
        utils.fatal_error(
            f"Failed to checkout {name} {repo_exists} {tmpurl} {repodir} {path}"
        )

    if tmpurl:
        print(git.git_operation("restore", ".gitmodules"))

    return

def add_remote(git, url):
    remotes = git.git_operation("remote", "-v")
    newremote = "newremote.00"
    if url in remotes:
        for line in remotes:
            if url in line and "fetch" in line:
                newremote = line.split()[0]
                break
    else:
        i = 0
        while "newremote" in remotes:
            i = i + 1
            newremote = f"newremote.{i:02d}"
        git.git_operation("remote", "add", newremote, url)
    return newremote

def submodules_status(gitmodules, root_dir, toplevel=False):
    testfails = 0
    localmods = 0
    needsupdate = 0
    for name in gitmodules.sections():
        path = gitmodules.get(name, "path")
        tag = gitmodules.get(name, "fxtag")
        url = gitmodules.get(name, "url")
        required = gitmodules.get(name, "fxrequired")
        level = required and "Toplevel" in required
        if not path:
            utils.fatal_error("No path found in .gitmodules for {}".format(name))
        newpath = os.path.join(root_dir, path)
        logger.debug("newpath is {}".format(newpath))
        if not os.path.exists(os.path.join(newpath, ".git")):
            rootgit = GitInterface(root_dir, logger)
            # submodule commands use path, not name
            url = url.replace("git@github.com:", "https://github.com/")
            tags = rootgit.git_operation("ls-remote", "--tags", url)
            result = rootgit.git_operation("submodule","status",newpath).split()
            ahash = None
            if result:
                ahash = result[0][1:]
            hhash = None
            atag = None
            needsupdate += 1
            if not toplevel and level:
                continue
            for htag in tags.split("\n"):
                if htag.endswith('^{}'):
                    htag = htag[:-3]
                if ahash and not atag and ahash in htag:
                    atag = (htag.split()[1])[10:]
                if tag and not hhash and htag.endswith(tag):
                    hhash = htag.split()[0]
                if hhash and atag:
                    break
            if tag and (ahash == hhash or atag == tag):
                print(f"e {name:>20} not checked out, aligned at tag {tag}")
            elif tag:
                ahash = rootgit.git_operation(
                    "submodule", "status", "{}".format(path)
                ).rstrip()
                ahash = ahash[1 : len(tag) + 1]
                if tag == ahash:
                    print(f"e {name:>20} not checked out, aligned at hash {ahash}")
                else:
                    print(
                        f"e {name:>20} not checked out, out of sync at tag {atag}, expected tag is {tag}"
                    )
                    testfails += 1
            else:
                print(f"e {name:>20} has no fxtag defined in .gitmodules")
                testfails += 1
        else:
            with utils.pushd(newpath):
                git = GitInterface(newpath, logger)
                atag = git.git_operation("describe", "--tags", "--always").rstrip()
                ahash =  git.git_operation("rev-list", "HEAD").partition("\n")[0]
                rurl = git.git_operation("ls-remote","--get-url").rstrip()
                if rurl != url:
                    remote = add_remote(git, url)
                    git.git_operation("fetch", remote)
                if tag and atag == tag:
                    print(f"  {name:>20} at tag {tag}")
                elif tag and ahash[: len(tag)] == tag:
                    print(f"  {name:>20} at hash {ahash}")
                elif atag == ahash:
                    print(f"  {name:>20} at hash {ahash}")
                elif tag:
                    print(
                        f"s {name:>20} {atag} {ahash} is out of sync with .gitmodules {tag}"
                    )
                    testfails += 1
                    needsupdate += 1
                else:
                    print(
                        f"e {name:>20} has no fxtag defined in .gitmodules, module at {atag}"
                    )
                    testfails += 1

                status = git.git_operation("status", "--ignore-submodules", "-uno")
                if "nothing to commit" not in status:
                    localmods = localmods + 1
                    print("M" + textwrap.indent(status, "                      "))

    return testfails, localmods, needsupdate


def submodules_update(gitmodules, root_dir, requiredlist, force):
    _, localmods, needsupdate = submodules_status(gitmodules, root_dir)

    if localmods and not force:
        local_mods_output()
        return
    if needsupdate == 0:
        return

    for name in gitmodules.sections():
        fxtag = gitmodules.get(name, "fxtag")
        path = gitmodules.get(name, "path")
        url = gitmodules.get(name, "url")
        logger.info(
            "name={} path={} url={} fxtag={} requiredlist={} ".format(
                name, os.path.join(root_dir, path), url, fxtag, requiredlist
            )
        )

        fxrequired = gitmodules.get(name, "fxrequired")
        assert fxrequired in fxrequired_allowed_values()
        rgit = GitInterface(root_dir, logger)
        superroot = rgit.git_operation("rev-parse", "--show-superproject-working-tree")

        fxsparse = gitmodules.get(name, "fxsparse")

        if (
            fxrequired
            and (superroot and "Toplevel" in fxrequired)
            or fxrequired not in requiredlist
        ):
            if "ToplevelOptional" == fxrequired:
                print("Skipping optional component {}".format(name))
            continue
        if fxsparse:
            logger.debug(
                "Callng submodule_sparse_checkout({}, {}, {}, {}, {}, {}".format(
                    root_dir, name, url, path, fxsparse, fxtag
                )
            )
            submodule_sparse_checkout(root_dir, name, url, path, fxsparse, tag=fxtag)
        else:
            logger.info(
                "Calling submodule_checkout({},{},{},{})".format(
                    root_dir, name, path, url
                )
            )

            single_submodule_checkout(
                root_dir,
                name,
                path,
                url=url,
                tag=fxtag,
                force=force,
                optional=("AlwaysOptional" in requiredlist),
            )

        if os.path.exists(os.path.join(path, ".git")):
            submoddir = os.path.join(root_dir, path)
            with utils.pushd(submoddir):
                git = GitInterface(submoddir, logger)
                # first make sure the url is correct
                upstream = git.git_operation("ls-remote", "--get-url").rstrip()
                newremote = "origin"
                if upstream != url:
                    add_remote(git, url)

                tags = git.git_operation("tag", "-l")
                if fxtag and fxtag not in tags:
                    git.git_operation("fetch", newremote, "--tags")
                atag = git.git_operation("describe", "--tags", "--always").rstrip()
                if fxtag and fxtag != atag:
                    try:
                        git.git_operation("checkout", fxtag)
                        print(f"{name:>20} updated to {fxtag}")
                    except Exception as error:
                        print(error)
                elif not fxtag:
                    print(f"No fxtag found for submodule {name:>20}")
                else:
                    print(f"{name:>20} up to date.")




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


# checkout is done by update if required so this function may be depricated
def submodules_checkout(gitmodules, root_dir, requiredlist, force=False):
    """
    This function checks out all git submodules based on the provided parameters.

    Parameters:
    gitmodules (ConfigParser): The gitmodules configuration.
    root_dir (str): The root directory for the git operation.
    requiredlist (list): The list of required modules.
    force (bool, optional): If set to True, forces the checkout operation. Defaults to False.

    Returns:
    None
    """
    # function implementation...
    print("")
    _, localmods, needsupdate = submodules_status(gitmodules, root_dir)
    if localmods and not force:
        local_mods_output()
        return
    if not needsupdate:
        return
    for name in gitmodules.sections():
        fxrequired = gitmodules.get(name, "fxrequired")
        fxsparse = gitmodules.get(name, "fxsparse")
        fxtag = gitmodules.get(name, "fxtag")
        path = gitmodules.get(name, "path")
        url = gitmodules.get(name, "url")
        if fxrequired and fxrequired not in requiredlist:
            if "Optional" in fxrequired:
                print("Skipping optional component {}".format(name))
            continue

        if fxsparse:
            logger.debug(
                "Callng submodule_sparse_checkout({}, {}, {}, {}, {}, {}".format(
                    root_dir, name, url, path, fxsparse, fxtag
                )
            )
            submodule_sparse_checkout(root_dir, name, url, path, fxsparse, tag=fxtag)
        else:
            logger.debug(
                "Calling submodule_checkout({},{},{})".format(root_dir, name, path)
            )
            single_submodule_checkout(
                root_dir,
                name,
                path,
                url=url,
                tag=fxtag,
                force=force,
                optional="AlwaysOptional" in requiredlist,
            )


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
        fxurl = gitmodules.get(name, "fxDONOTMODIFYurl")
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
        sys.exit("No submodule components found")
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
