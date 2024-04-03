#!/usr/bin/env python
from configparser import ConfigParser
import sys
import shutil
from pathlib import Path
import argparse
import logging
from git_fleximod.gitinterface import GitInterface
from git_fleximod.gitmodules import GitModules
from git_fleximod import utils

logger = None

def find_root_dir(filename=".git"):
    d = Path.cwd()
    root = Path(d.root)
    while d != root:
        attempt = d / filename
        if attempt.is_dir():
            return d
        d = d.parent
    return None


def get_parser():
    description = """
    %(prog)s manages checking out groups of gitsubmodules with addtional support for Earth System Models
    """
    parser = argparse.ArgumentParser(
        description=description, formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument('-e', '--externals', nargs='?',
                        default='Externals.cfg',
                        help='The externals description filename. '
                        'Default: %(default)s.')

    parser.add_argument(
        "-C",
        "--path",
        default=find_root_dir(),
        help="Toplevel repository directory.  Defaults to top git directory relative to current.",
    )

    parser.add_argument(
        "-g",
        "--gitmodules",
        nargs="?",
        default=".gitmodules",
        help="The submodule description filename. " "Default: %(default)s.",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="count",
        default=0,
        help="Output additional information to "
        "the screen and log file. This flag can be "
        "used up to two times, increasing the "
        "verbosity level each time.",
    )
    parser.add_argument(
        "-d",
        "--debug",
        action="store_true",
        default=False,
        help="DEVELOPER: output additional debugging "
        "information to the screen and log file.",
    )

    return parser

def commandline_arguments(args=None):
    parser = get_parser()

    options = parser.parse_args(args)
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

    return(
        options.path,
        options.gitmodules,
        options.externals
        )

class ExternalRepoTranslator:
    """
    Translates external repositories configured in an INI-style externals file.
    """

    def __init__(self, rootpath, gitmodules, externals):
        self.rootpath = rootpath
        if gitmodules:
            self.gitmodules = GitModules(logger, confpath=rootpath)
        self.externals = (rootpath / Path(externals)).resolve()
        print(f"Translating {self.externals}")
        self.git = GitInterface(rootpath, logger)
        
#    def __del__(self):
#        if (self.rootpath / "save.gitignore"):
            

    def translate_single_repo(self, section, tag, url, path, efile, hash_, sparse, protocol):
        """
        Translates a single repository based on configuration details.

        Args:
            rootpath (str): Root path of the main repository.
            gitmodules (str): Path to the .gitmodules file.
            tag (str): The tag to use for the external repository.
            url (str): The URL of the external repository.
            path (str): The relative path within the main repository for the external repository.
            efile (str): The external file or file containing submodules.
            hash_ (str): The commit hash to checkout (if applicable).
            sparse (str):  Boolean indicating whether to use sparse checkout (if applicable).
            protocol (str): The protocol to use (e.g., 'git', 'http').
        """
        assert protocol != "svn", "SVN protocol is not currently supported"
        print(f"Translating repository {section}")
        if efile:
            file_path = Path(path) / Path(efile)
            newroot = (self.rootpath / file_path).parent.resolve()
            if not newroot.exists():
                newroot.mkdir(parents=True)
            logger.info("Newroot is {}".format(newroot))
            newt = ExternalRepoTranslator(newroot, ".gitmodules", efile)
            newt.translate_repo()
        if protocol == "externals_only":
            if tag:
                self.gitmodules.set(section, "fxtag", tag)
            if hash_:
                self.gitmodules.set(section, "fxtag", hash_)
            
            self.gitmodules.set(section, "fxDONOTUSEurl", url)
            if sparse:
                self.gitmodules.set(section, "fxsparse", sparse)
            self.gitmodules.set(section, "fxrequired", "ToplevelRequired")
        else:
            newpath = (self.rootpath / Path(path))
            if newpath.exists():
                shutil.rmtree(newpath)
                logger.info("Creating directory {}".format(newpath))
            newpath.mkdir(parents=True)
            if tag:
                logger.info("cloning {}".format(section))
                try:
                    self.git.git_operation("clone", "-b", tag, "--depth", "1", url, path)
                except:
                    self.git.git_operation("clone", url, path)
                    with utils.pushd(newpath):
                        ngit = GitInterface(newpath, logger)
                        ngit.git_operation("checkout", tag)
            if hash_:
                self.git.git_operation("clone", url, path)
                git = GitInterface(newpath, logger)
                git.git_operation("fetch", "origin")
                git.git_operation("checkout", hash_)
            if sparse:
                print("setting as sparse submodule {}".format(section))
                sparsefile = (newpath / Path(sparse))
                newfile = (newpath / ".git" / "info" / "sparse-checkout")
                print(f"sparsefile {sparsefile} newfile {newfile}")
                shutil.copy(sparsefile, newfile)
        
            logger.info("adding submodule {}".format(section))        
            self.gitmodules.save()
            self.git.git_operation("submodule", "add", "-f", "--name", section, url, path)
            self.git.git_operation("submodule","absorbgitdirs")
            self.gitmodules.reload()
            if tag:
                self.gitmodules.set(section, "fxtag", tag)
            if hash_:
                self.gitmodules.set(section, "fxtag", hash_)
            
            self.gitmodules.set(section, "fxDONOTUSEurl", url)
            if sparse:
                self.gitmodules.set(section, "fxsparse", sparse)
            self.gitmodules.set(section, "fxrequired", "ToplevelRequired")
    
        
    def translate_repo(self):
        """
        Translates external repositories defined within an external file.

        Args:
            rootpath (str): Root path of the main repository.
            gitmodules (str): Path to the .gitmodules file.
            external_file (str): The path to the external file containing repository definitions.
        """
        econfig = ConfigParser()
        econfig.read((self.rootpath / Path(self.externals)))

        for section in econfig.sections():
            if section == "externals_description":
                logger.info("skipping section {}".format(section))
                return
            logger.info("Translating section {}".format(section))
            tag = econfig.get(section, "tag", raw=False, fallback=None)
            url = econfig.get(section, "repo_url", raw=False, fallback=None)
            path = econfig.get(section, "local_path", raw=False, fallback=None)
            efile = econfig.get(section, "externals", raw=False, fallback=None)
            hash_ = econfig.get(section, "hash", raw=False, fallback=None)
            sparse = econfig.get(section, "sparse", raw=False, fallback=None)
            protocol = econfig.get(section, "protocol", raw=False, fallback=None)

            self.translate_single_repo(section, tag, url, path, efile, hash_, sparse, protocol)



def _main():
    rootpath, gitmodules, externals = commandline_arguments()
    global logger
    logger = logging.getLogger(__name__)
    with utils.pushd(rootpath):
        t = ExternalRepoTranslator(Path(rootpath), gitmodules, externals)
        logger.info("Translating {}".format(rootpath))
        t.translate_repo()

        
if __name__ == "__main__":
    sys.exit(_main())
