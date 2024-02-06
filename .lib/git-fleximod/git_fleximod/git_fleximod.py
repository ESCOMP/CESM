#!/usr/bin/env python
import sys
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


def commandline_arguments(args=None):
    parser = cli.get_parser()

    if args:
        options = parser.parse_args(args)
    else:
        options = parser.parse_args()

    # explicitly listing a component overrides the optional flag
    if options.optional or options.components:
        fxrequired = ["T:T", "T:F", "I:T"]
    else:
        fxrequired = ["T:T", "I:T"]

    action = options.action
    if not action:
        action = "checkout"
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
    # first create the module directory
    if not os.path.isdir(os.path.join(root_dir,path)):
        os.makedirs(os.path.join(root_dir,path))
    # Check first if the module is already defined
    # and the sparse-checkout file exists
    git = GitInterface(root_dir, logger)

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
    sprepo_git.git_operation("remote", "add", "origin", url)

    superroot = git.git_operation("rev-parse", "--show-superproject-working-tree")
    if os.path.isfile(os.path.join(root_dir, ".git")):
        with open(os.path.join(root_dir, ".git")) as f:
            gitpath = os.path.abspath(os.path.join(root_dir, f.read().split()[1]))
        topgit = os.path.abspath(os.path.join(gitpath, "modules"))
    else:
        topgit = os.path.abspath(os.path.join(root_dir, ".git", "modules"))

    if not os.path.isdir(topgit):
        os.makedirs(topgit)
    topgit = os.path.join(topgit, name)
    logger.debug(
        "root_dir is {} topgit is {} superroot is {}".format(
            root_dir, topgit, superroot
        )
    )

    if os.path.isdir(os.path.join(root_dir, path, ".git")):
        shutil.move(os.path.join(root_dir, path, ".git"), topgit)
        with open(os.path.join(root_dir, path, ".git"), "w") as f:
            f.write("gitdir: " + os.path.relpath(topgit, os.path.join(root_dir, path)))

    gitsparse = os.path.abspath(os.path.join(topgit, "info", "sparse-checkout"))
    if os.path.isfile(gitsparse):
        logger.warning("submodule {} is already initialized".format(name))
        return

    shutil.copy(os.path.join(root_dir, path, sparsefile), gitsparse)

    # Finally checkout the repo
    sprepo_git.git_operation("fetch", "--depth=1", "origin", "--tags")
    sprepo_git.git_operation("checkout", tag)
    print(f"Successfully checked out {name}")


def single_submodule_checkout(root, name, path, url=None, tag=None, force=False):
    git = GitInterface(root, logger)
    repodir = os.path.join(root, path)
    if os.path.exists(os.path.join(repodir, ".git")):
        logger.info("Submodule {} already checked out".format(name))
        return
    # if url is provided update to the new url
    tmpurl = None

    # Look for a .gitmodules file in the newly checkedout repo
    if url:
        # ssh urls cause problems for those who dont have git accounts with ssh keys defined
        # but cime has one since e3sm prefers ssh to https, because the .gitmodules file was
        # opened with a GitModules object we don't need to worry about restoring the file here
        # it will be done by the GitModules class
        if url.startswith("git@"):
            tmpurl = url
            url = url.replace("git@github.com:", "https://github.com")
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

            newpath = os.path.abspath(os.path.join(root, rootdotgit, "modules", path))
            if not os.path.isdir(os.path.join(newpath, os.pardir)):
                os.makedirs(os.path.abspath(os.path.join(newpath, os.pardir)))

            shutil.move(os.path.join(repodir, ".git"), newpath)
            with open(os.path.join(repodir, ".git"), "w") as f:
                f.write("gitdir: " + newpath)

    if not tmpurl:
        logger.debug(git.git_operation("submodule", "update", "--init", "--", path))

    if os.path.exists(os.path.join(repodir, ".gitmodules")):
        # recursively handle this checkout
        print(f"Recursively checking out submodules of {name} {repodir} {url}")
        gitmodules = GitModules(logger, confpath=repodir)
        submodules_checkout(gitmodules, repodir, ["I:T"], force=force)
    if os.path.exists(os.path.join(repodir, ".git")):
        print(f"Successfully checked out {name}")
    else:
        utils.fatal_error(f"Failed to checkout {name}")

    if tmpurl:
        print(git.git_operation("restore", ".gitmodules"))

    return


def submodules_status(gitmodules, root_dir):
    testfails = 0
    localmods = 0
    for name in gitmodules.sections():
        path = gitmodules.get(name, "path")
        tag = gitmodules.get(name, "fxtag")
        if not path:
            utils.fatal_error("No path found in .gitmodules for {}".format(name))
        newpath = os.path.join(root_dir, path)
        logger.debug("newpath is {}".format(newpath))
        if not os.path.exists(os.path.join(newpath, ".git")):
            rootgit = GitInterface(root_dir, logger)
            # submodule commands use path, not name
            url = gitmodules.get(name, "url")
            tags = rootgit.git_operation("ls-remote", "--tags", url)
            atag = None
            for htag in tags.split("\n"):
                if tag and tag in htag:
                    atag = (htag.split()[1])[10:]
                    break
            if tag and tag == atag:
                print(f"e {name:>20} not checked out, aligned at tag {tag}")
            elif tag:
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
                if tag and atag != tag:
                    print(f"s {name:>20} {atag} is out of sync with .gitmodules {tag}")
                    testfails += 1
                elif tag:
                    print(f"  {name:>20} at tag {tag}")
                else:
                    print(
                        f"e {name:>20} has no tag defined in .gitmodules, module at {atag}"
                    )
                    testfails += 1

                status = git.git_operation("status", "--ignore-submodules")
                if "nothing to commit" not in status:
                    localmods = localmods + 1
                    print("M" + textwrap.indent(status, "                      "))

    return testfails, localmods


def submodules_update(gitmodules, root_dir, force):
    _, localmods = submodules_status(gitmodules, root_dir)
    print("")
    if localmods and not force:
        print(
            "Repository has local mods, cowardly refusing to continue, fix issues or use --force to override"
        )
        return
    for name in gitmodules.sections():
        fxtag = gitmodules.get(name, "fxtag")
        path = gitmodules.get(name, "path")
        url = gitmodules.get(name, "url")
        logger.info("name={} path={} url={} fxtag={}".format(name, path, url, fxtag))
        if os.path.exists(os.path.join(path, ".git")):
            submoddir = os.path.join(root_dir, path)
            with utils.pushd(submoddir):
                git = GitInterface(submoddir, logger)
                # first make sure the url is correct
                upstream = git.git_operation("ls-remote", "--get-url").rstrip()
                newremote = "origin"
                if upstream != url:
                    # TODO - this needs to be a unique name
                    remotes = git.git_operation("remote", "-v")
                    if url in remotes:
                        for line in remotes:
                            if url in line and "fetch" in line:
                                newremote = line.split()[0]
                                break
                    else:
                        i = 0
                        while newremote in remotes:
                            i = i + 1
                            newremote = f"newremote.{i:02d}"
                        git.git_operation("remote", "add", newremote, url)

                tags = git.git_operation("tag", "-l")
                if fxtag and fxtag not in tags:
                    git.git_operation("fetch", newremote, "--tags")
                atag = git.git_operation("describe", "--tags", "--always").rstrip()

                if fxtag and fxtag != atag:
                    print(f"{name:>20} updated to {fxtag}")
                    git.git_operation("checkout", fxtag)
                elif not fxtag:
                    print(f"No fxtag found for submodule {name:>20}")
                else:
                    print(f"{name:>20} up to date.")


def submodules_checkout(gitmodules, root_dir, requiredlist, force=False):
    _, localmods = submodules_status(gitmodules, root_dir)
    print("")
    if localmods and not force:
        print(
            "Repository has local mods, cowardly refusing to continue, fix issues or use --force to override"
        )
        return
    for name in gitmodules.sections():
        fxrequired = gitmodules.get(name, "fxrequired")
        fxsparse = gitmodules.get(name, "fxsparse")
        fxtag = gitmodules.get(name, "fxtag")
        path = gitmodules.get(name, "path")
        url = gitmodules.get(name, "url")

        if fxrequired and fxrequired not in requiredlist:
            if "T:F" == fxrequired:
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
                root_dir, name, path, url=url, tag=fxtag, force=force
            )


def submodules_test(gitmodules, root_dir):
    # First check that fxtags are present and in sync with submodule hashes
    testfails, localmods = submodules_status(gitmodules, root_dir)
    print("")
    # Then make sure that urls are consistant with fxurls (not forks and not ssh)
    # and that sparse checkout files exist
    for name in gitmodules.sections():
        url = gitmodules.get(name, "url")
        fxurl = gitmodules.get(name, "fxurl")
        fxsparse = gitmodules.get(name, "fxsparse")
        path = gitmodules.get(name, "path")
        if not fxurl or url != fxurl:
            print(f"{name:>20} url {url} not in sync with required {fxurl}")
            testfails += 1
        if fxsparse and not os.path.isfile(os.path.join(root_dir, path, fxsparse)):
            print(f"{name:>20} sparse checkout file {fxsparse} not found")
            testfails += 1
    return testfails + localmods


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

    logger.info("action is {}".format(action))

    if not os.path.isfile(os.path.join(root_dir, file_name)):
        file_path = utils.find_upwards(root_dir, file_name)

        if file_path is None:
            utils.fatal_error(
                "No {} found in {} or any of it's parents".format(file_name, root_dir)
            )

        root_dir = os.path.dirname(file_path)
    logger.info("root_dir is {}".format(root_dir))
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
        submodules_update(gitmodules, root_dir, force)
    elif action == "checkout":
        submodules_checkout(gitmodules, root_dir, fxrequired, force)
    elif action == "status":
        submodules_status(gitmodules, root_dir)
    elif action == "test":
        retval = submodules_test(gitmodules, root_dir)
    else:
        utils.fatal_error(f"unrecognized action request {action}")
    return retval


if __name__ == "__main__":
    sys.exit(main())
