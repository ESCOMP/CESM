import os
import textwrap
import shutil
from configparser import NoOptionError
from git_fleximod import utils
from git_fleximod.gitinterface import GitInterface

class Submodule():
    def __init__(self, root_dir, name, path, url, fxtag=None, fxurl=None, fxsparse=None, fxrequired=None, logger=None):
        self.name = name
        self.root_dir = root_dir
        self.path = path
        url = url.replace("git@github.com:", "https://github.com/")
        self.url = url
        self.fxurl = fxurl
        self.fxtag = fxtag
        self.fxsparse = fxsparse
        self.fxrequired = fxrequired
        self.logger = logger
       
    def status(self):
        smpath = os.path.join(self.root_dir, self.path)
        testfails = 0
        localmods = 0
        needsupdate = 0
        ahash = None
        optional = " (optional)" if "Optional" in self.fxrequired else None
        required = None
        level = None
        if not os.path.exists(os.path.join(smpath, ".git")):
            rootgit = GitInterface(self.root_dir, self.logger)
            # submodule commands use path, not name
            tags = rootgit.git_operation("ls-remote", "--tags", self.url)
            result = rootgit.git_operation("submodule","status",smpath).split()
            
            if result:
                ahash = result[0][1:]
            hhash = None
            atag = None
            for htag in tags.split("\n"):
                if htag.endswith('^{}'):
                    htag = htag[:-3]
                if ahash and not atag and ahash in htag:
                    atag = (htag.split()[1])[10:]
                if self.fxtag and not hhash and htag.endswith(self.fxtag):
                    hhash = htag.split()[0]
                if hhash and atag:
                    break
            if self.fxtag and (ahash == hhash or atag == self.fxtag):
                result = f"e {self.name:>20} not checked out, aligned at tag {self.fxtag}{optional} {level} {required}"
            elif self.fxtag:
                ahash = rootgit.git_operation(
                    "submodule", "status", "{}".format(self.path)
                ).rstrip()
                ahash = ahash[1 : len(self.fxtag) + 1]
                if self.fxtag == ahash:
                    result = f"e {self.name:>20} not checked out, aligned at hash {ahash}{optional}"
                else:
                    result = f"e {self.name:>20} not checked out, out of sync at tag {atag}, expected tag is {self.fxtag}{optional}"
                    testfails += 1
            else:
                result = f"e {self.name:>20} has no fxtag defined in .gitmodules{optional}"
                testfails += 1
        else:
            with utils.pushd(smpath):
                git = GitInterface(smpath, self.logger)
                remote = git.git_operation("remote").rstrip()
                if remote == '':
                    result = f"e {self.name:>20} has no associated remote"
                    testfails += 1
                    needsupdate += 1
                    return result, needsupdate, localmods, testfails                    
                rurl = git.git_operation("ls-remote","--get-url").rstrip()
                atag = git.git_operation("describe", "--tags", "--always").rstrip()
                ahash =  git.git_operation("rev-list", "HEAD").partition("\n")[0]
                    
                recurse = False
                if rurl != self.url:
                    remote = self._add_remote(git)
                    git.git_operation("fetch", remote)
                if self.fxtag and atag == self.fxtag:
                    result = f"  {self.name:>20} at tag {self.fxtag}"
                    recurse = True
                elif self.fxtag and ahash[: len(self.fxtag)] == self.fxtag:
                    result = f"  {self.name:>20} at hash {ahash}"
                    recurse = True
                elif atag == ahash:
                    result = f"  {self.name:>20} at hash {ahash}"
                    recurse = True
                elif self.fxtag:
                    result = f"s {self.name:>20} {atag} {ahash} is out of sync with .gitmodules {self.fxtag}"
                    testfails += 1
                    needsupdate += 1
                else:
                    result = f"e {self.name:>20} has no fxtag defined in .gitmodules, module at {atag}"
                    testfails += 1
                    
                status = git.git_operation("status", "--ignore-submodules", "-uno")
                if "nothing to commit" not in status:
                    localmods = localmods + 1
                    result = "M" + textwrap.indent(status, "                      ")
        
        return result, needsupdate, localmods, testfails

    
    def _add_remote(self, git):
        remotes = git.git_operation("remote", "-v").splitlines()
        upstream = None
        if remotes:
            upstream = git.git_operation("ls-remote", "--get-url").rstrip()
            newremote = "newremote.00"

            line = next((s for s in remotes if self.url in s), None)
            if line:
                newremote = line.split()[0]
                return newremote
            else:
                i = 0
                while "newremote" in remotes:
                    i = i + 1
                    newremote = f"newremote.{i:02d}"
        else:
            newremote = "origin"
        git.git_operation("remote", "add", newremote, self.url)
        return newremote

    def toplevel(self):
        if self.fxrequired:
            return True if self.fxrequired.startswith("Top") else False

    def sparse_checkout(self):
        """
            This function performs a sparse checkout of a git submodule.  It does so by first creating the .git/info/sparse-checkout fileq
            in the submodule and then checking out the desired tag.  If the submodule is already checked out, it will not be checked out again.
            Creating the sparse-checkout file first prevents the entire submodule from being checked out and then removed.  This is important
            because the submodule may have a large number of files and checking out the entire submodule and then removing it would be time
            and disk space consuming.

            Returns:
            None
        """
        self.logger.info("Called sparse_checkout for {}".format(self.name))
        rgit = GitInterface(self.root_dir, self.logger)
        superroot = rgit.git_operation("rev-parse", "--show-superproject-working-tree")
        if superroot:
            gitroot = superroot.strip()
        else:
            gitroot = self.root_dir.strip()
        assert os.path.isdir(os.path.join(gitroot, ".git"))
        # first create the module directory
        if not os.path.isdir(os.path.join(self.root_dir, self.path)):
            os.makedirs(os.path.join(self.root_dir, self.path))

        # initialize a new git repo and set the sparse checkout flag
        sprep_repo = os.path.join(self.root_dir, self.path)
        sprepo_git = GitInterface(sprep_repo, self.logger)
        if os.path.exists(os.path.join(sprep_repo, ".git")):
            try:
                self.logger.info("Submodule {} found".format(self.name))
                chk = sprepo_git.config_get_value("core", "sparseCheckout")
                if chk == "true":
                    self.logger.info("Sparse submodule {} already checked out".format(self.name))
                    return
            except (NoOptionError):
                self.logger.debug("Sparse submodule {} not present".format(self.name))
            except Exception as e:
                utils.fatal_error("Unexpected error {} occured.".format(e))

        sprepo_git.config_set_value("core", "sparseCheckout", "true")

        # set the repository remote
        
        self.logger.info("Setting remote origin in {}/{}".format(self.root_dir, self.path))
        status = sprepo_git.git_operation("remote", "-v")
        if self.url not in status:
            sprepo_git.git_operation("remote", "add", "origin", self.url)

        topgit = os.path.join(gitroot, ".git")

        if gitroot != self.root_dir and os.path.isfile(os.path.join(self.root_dir, ".git")):
            with open(os.path.join(self.root_dir, ".git")) as f:
                gitpath = os.path.relpath(
                    os.path.join(self.root_dir, f.read().split()[1]),
                    start=os.path.join(self.root_dir, self.path),
                )
                topgit = os.path.join(gitpath, "modules")
        else:
            topgit = os.path.relpath(
                os.path.join(self.root_dir, ".git", "modules"),
                start=os.path.join(self.root_dir, self.path),
            )

        with utils.pushd(sprep_repo):
            if not os.path.isdir(topgit):
                os.makedirs(topgit)
        topgit += os.sep + self.name

        if os.path.isdir(os.path.join(self.root_dir, self.path, ".git")):
            with utils.pushd(sprep_repo):
                if os.path.isdir(os.path.join(topgit,".git")):
                    shutil.rmtree(os.path.join(topgit,".git"))
                shutil.move(".git", topgit)
                with open(".git", "w") as f:
                    f.write("gitdir: " + os.path.relpath(topgit))
                #    assert(os.path.isdir(os.path.relpath(topgit, start=sprep_repo)))
                gitsparse = os.path.abspath(os.path.join(topgit, "info", "sparse-checkout"))
            if os.path.isfile(gitsparse):
                self.logger.warning(
                    "submodule {} is already initialized {}".format(self.name, topgit)
                )
                return

            with utils.pushd(sprep_repo):
                if os.path.isfile(self.fxsparse):
                    shutil.copy(self.fxsparse, gitsparse)
                

        # Finally checkout the repo
        sprepo_git.git_operation("fetch", "origin", "--tags")
        sprepo_git.git_operation("checkout", self.fxtag)

        print(f"Successfully checked out {self.name:>20} at {self.fxtag}")
        rgit.config_set_value(f'submodule "{self.name}"', "active", "true")
        rgit.config_set_value(f'submodule "{self.name}"', "url", self.url)

    def update(self, optional=None):
            # function implementation...
        git = GitInterface(self.root_dir, self.logger)
        repodir = os.path.join(self.root_dir, self.path)
        self.logger.info("Checkout {} into {}/{}".format(self.name, self.root_dir, self.path))
        # if url is provided update to the new url
        tmpurl = None
        repo_exists = False
        #    if os.path.exists(os.path.join(repodir, ".git")):
        #        self.logger.info("Submodule {} already checked out".format(self.name))
        #        repo_exists = True
        # Look for a .gitmodules file in the newly checkedout repo
        if self.fxsparse:
            print(f"Sparse checkout {self.name} fxsparse {self.fxsparse}")
            self.sparse_checkout()
        else:
            if not repo_exists and self.url:
                # ssh urls cause problems for those who dont have git accounts with ssh keys defined
                # but cime has one since e3sm prefers ssh to https, because the .gitmodules file was
                # opened with a GitModules object we don't need to worry about restoring the file here
                # it will be done by the GitModules class
                if self.url.startswith("git@"):
                    tmpurl = self.url
                    url = self.url.replace("git@github.com:", "https://github.com/")
                    git.git_operation("clone", url, self.path)
                    smgit = GitInterface(repodir, self.logger)
                    if not tag:
                        tag = smgit.git_operation("describe", "--tags", "--always").rstrip()
                    smgit.git_operation("checkout", tag)
                    # Now need to move the .git dir to the submodule location
                    rootdotgit = os.path.join(self.root_dir, ".git")
                    if os.path.isfile(rootdotgit):
                        with open(rootdotgit) as f:
                            line = f.readline()
                            if line.startswith("gitdir: "):
                                rootdotgit = line[8:].rstrip()

                    newpath = os.path.abspath(os.path.join(self.root_dir, rootdotgit, "modules", self.name))
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
                git.git_operation("submodule", "add", "--name", self.name, "--", url, self.path) 

            if not repo_exists or not tmpurl:
                git.git_operation("submodule", "update", "--init", "--", self.path)

            if self.fxtag and not optional:        
                smgit = GitInterface(repodir, self.logger)
                smgit.git_operation("checkout", self.fxtag)

            if os.path.exists(os.path.join(repodir, ".gitmodules")):
                # recursively handle this checkout
                print(f"Recursively checking out submodules of {self.name} {optional}")
                gitmodules = GitModules(self.logger, confpath=repodir)
                requiredlist = ["AlwaysRequired"]
                if optional:
                    requiredlist.append("AlwaysOptional")
                submodules_checkout(gitmodules, repodir, requiredlist, force=force)
            if not os.path.exists(os.path.join(repodir, ".git")):
                utils.fatal_error(
                    f"Failed to checkout {self.name} {repo_exists} {tmpurl} {repodir} {self.path}"
                )
                
            if tmpurl:
                print(git.git_operation("restore", ".gitmodules"))
        if os.path.exists(os.path.join(self.path, ".git")):
            submoddir = os.path.join(self.root_dir, self.path)
            with utils.pushd(submoddir):
                git = GitInterface(submoddir, self.logger)
                # first make sure the url is correct
                print("3calling ls-remote")

                newremote = self._add_remote(git)

                tags = git.git_operation("tag", "-l")
                fxtag = self.fxtag
                if fxtag and fxtag not in tags:
                    git.git_operation("fetch", newremote, "--tags")
                atag = git.git_operation("describe", "--tags", "--always").rstrip()
                if fxtag and fxtag != atag:
                    try:
                        git.git_operation("checkout", fxtag)
                        print(f"{self.name:>20} updated to {fxtag}")
                    except Exception as error:
                        print(error)
                    

                elif not fxtag:
                    print(f"No fxtag found for submodule {self.name:>20}")
                else:
                    print(f"{self.name:>20} up to date.")


                
        return
