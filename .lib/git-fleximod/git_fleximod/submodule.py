import os
import textwrap
import shutil
import string
from configparser import NoOptionError
from git_fleximod import utils
from git_fleximod.gitinterface import GitInterface

class Submodule():
    """
    Represents a Git submodule with enhanced features for flexible management.

    Attributes:
        name (str): The name of the submodule.
        root_dir (str): The root directory of the main project.
        path (str): The relative path from the root directory to the submodule.
        url (str): The URL of the submodule repository.
        fxurl (str): The URL for flexible submodule management (optional).
        fxtag (str): The tag for flexible submodule management (optional).
        fxsparse (str): Path to the sparse checkout file relative to the submodule path, see git-sparse-checkout for details (optional).
        fxrequired (str): Indicates if the submodule is optional or required (optional).
        logger (logging.Logger): Logger instance for logging (optional).
    """
    def __init__(self, root_dir, name, path, url, fxtag=None, fxurl=None, fxsparse=None, fxrequired=None, logger=None):
        """
        Initializes a new Submodule instance with the provided attributes.
        """
        self.name = name
        self.root_dir = root_dir
        self.path = path 
        self.url = url
        self.fxurl = fxurl
        self.fxtag = fxtag
        self.fxsparse = fxsparse
        if fxrequired:
            self.fxrequired = fxrequired
        else:
            self.fxrequired = "AlwaysRequired"
        self.logger = logger
       
    def status(self):
        """
        Checks the status of the submodule and returns 4 parameters:
        - result (str): The status of the submodule.
        - needsupdate (bool): An indicator if the submodule needs to be updated.
        - localmods (bool): An indicator if the submodule has local modifications.
        - testfails (bool): An indicator if the submodule has failed a test, this is used for testing purposes.        
        """

        smpath = os.path.join(self.root_dir, self.path)
        testfails = False
        localmods = False
        needsupdate = False
        ahash = None
        optional = ""
        if "Optional" in self.fxrequired:
            optional = " (optional)" 
        required = None
        level = None
        if not os.path.exists(os.path.join(smpath, ".git")):
            rootgit = GitInterface(self.root_dir, self.logger)
            # submodule commands use path, not name
            status, tags = rootgit.git_operation("ls-remote", "--tags", self.url)
            status, result = rootgit.git_operation("submodule","status",smpath)
            result = result.split()
            
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
                result = f"e {self.name:>20} not checked out, aligned at tag {self.fxtag}{optional}"
                needsupdate = True
            elif self.fxtag:
                status, ahash = rootgit.git_operation(
                    "submodule", "status", "{}".format(self.path)
                )
                ahash = ahash[1 : len(self.fxtag) + 1]
                if self.fxtag == ahash:
                    result = f"e {self.name:>20} not checked out, aligned at hash {ahash}{optional}"
                else:
                    result = f"e {self.name:>20} not checked out, out of sync at tag {atag}, expected tag is {self.fxtag}{optional}"
                    testfails = True
                needsupdate = True
            else:
                result = f"e {self.name:>20} has no fxtag defined in .gitmodules{optional}"
                testfails = False
        else:
            with utils.pushd(smpath):
                git = GitInterface(smpath, self.logger)
                status, remote = git.git_operation("remote")
                if remote == '':
                    result = f"e {self.name:>20} has no associated remote"
                    testfails = True
                    needsupdate = True
                    return result, needsupdate, localmods, testfails                    
                status, rurl = git.git_operation("ls-remote","--get-url")
                status, lines = git.git_operation("log", "--pretty=format:\"%h %d\"")
                line = lines.partition('\n')[0]
                parts = line.split()
                ahash = parts[0][1:]
                atag = None
                if len(parts) > 3:
                    idx = 0
                    while idx < len(parts)-1:
                        idx = idx+1
                        if parts[idx] == 'tag:':
                            atag = parts[idx+1]
                            while atag.endswith(')') or atag.endswith(',') or atag.endswith("\""):
                                atag = atag[:-1]
                            if atag == self.fxtag:
                                break

                
                #print(f"line is {line} ahash is {ahash} atag is {atag} {parts}")
                #                atag = git.git_operation("describe", "--tags", "--always")
                # ahash =  git.git_operation("rev-list", "HEAD").partition("\n")[0]
                    
                recurse = False
                if rurl != self.url:
                    remote = self._add_remote(git)
                    git.git_operation("fetch", remote)
                if self.fxtag and atag == self.fxtag:
                    result = f"  {self.name:>20} at tag {self.fxtag}"
                    recurse = True
                    testfails = False
                elif self.fxtag and (ahash[: len(self.fxtag)] == self.fxtag or (self.fxtag.find(ahash)==0)):
                    result = f"  {self.name:>20} at hash {ahash}"
                    recurse = True
                    testfails = False
                elif atag == ahash:
                    result = f"  {self.name:>20} at hash {ahash}"
                    recurse = True
                elif self.fxtag:
                    result = f"s {self.name:>20} {atag} {ahash} is out of sync with .gitmodules {self.fxtag}"
                    testfails = True
                    needsupdate = True
                else:
                    if atag:
                        result = f"e {self.name:>20} has no fxtag defined in .gitmodules, module at {atag}"
                    else:
                        result = f"e {self.name:>20} has no fxtag defined in .gitmodules, module at {ahash}"
                    testfails = False
                    
                status, output = git.git_operation("status", "--ignore-submodules", "-uno")
                if "nothing to commit" not in output:
                    localmods = True
                    result = "M" + textwrap.indent(output, "                      ")
#        print(f"result {result} needsupdate {needsupdate} localmods {localmods} testfails {testfails}")
        return result, needsupdate, localmods, testfails

    
    def _add_remote(self, git):
        """
        Adds a new remote to the submodule if it does not already exist.

        This method checks the existing remotes of the submodule. If the submodule's URL is not already listed as a remote,
        it attempts to add a new remote. The name for the new remote is generated dynamically to avoid conflicts. If no
        remotes exist, it defaults to naming the new remote 'origin'.

        Args:
            git (GitInterface): An instance of GitInterface to perform git operations.

        Returns:
            str: The name of the new remote if added, or the name of the existing remote that matches the submodule's URL.
        """ 
        status, remotes = git.git_operation("remote", "-v")
        remotes = remotes.splitlines()
        upstream = None
        if remotes:
            status, upstream = git.git_operation("ls-remote", "--get-url")
            newremote = "newremote.00"
            tmpurl = self.url.replace("git@github.com:", "https://github.com/")
            line = next((s for s in remotes if self.url in s or tmpurl in s), None)
            if line:
                newremote = line.split()[0]
                return newremote
            else:
                i = 0
                while newremote in remotes:
                    i = i + 1
                    newremote = f"newremote.{i:02d}"
        else:
            newremote = "origin"
        git.git_operation("remote", "add", newremote, self.url)
        return newremote

    def toplevel(self):
        """
        Returns True if the submodule is Toplevel (either Required or Optional)
        """
        return True if "Top" in self.fxrequired else False

    def sparse_checkout(self):
        """
        Performs a sparse checkout of the submodule.

        This method optimizes the checkout process by only checking out files specified in the submodule's sparse-checkout configuration,
        rather than the entire submodule content. It achieves this by first ensuring the `.git/info/sparse-checkout` file is created and
        configured in the submodule's directory. Then, it proceeds to checkout the desired tag. If the submodule has already been checked out,
        this method will not perform the checkout again.

        This approach is particularly beneficial for submodules with a large number of files, as it significantly reduces the time and disk space
        required for the checkout process by avoiding the unnecessary checkout and subsequent removal of unneeded files.

        Returns:
            None
        """ 
        self.logger.info("Called sparse_checkout for {}".format(self.name))
        rgit = GitInterface(self.root_dir, self.logger)
        status, superroot = rgit.git_operation("rev-parse", "--show-superproject-working-tree")
        if superroot:
            gitroot = superroot.strip()
        else:
            gitroot = self.root_dir
        # Now need to move the .git dir to the submodule location
        rootdotgit = os.path.join(self.root_dir, ".git")
        while os.path.isfile(rootdotgit):
            with open(rootdotgit) as f:
                line = f.readline().rstrip()
                if line.startswith("gitdir: "):
                    rootdotgit = os.path.abspath(os.path.join(self.root_dir,line[8:]))
        assert os.path.isdir(rootdotgit)
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
        status, remotes = sprepo_git.git_operation("remote", "-v")
        if self.url not in remotes:
            sprepo_git.git_operation("remote", "add", "origin", self.url)

        topgit = os.path.join(gitroot, ".git")

        if gitroot != self.root_dir and os.path.isfile(os.path.join(self.root_dir, ".git")):
            with open(os.path.join(self.root_dir, ".git")) as f:
                gitpath = os.path.relpath(
                    os.path.join(self.root_dir, f.read().split()[1]),
                    start=os.path.join(self.root_dir, self.path),
                )
                rootdotgit = os.path.join(gitpath, "modules", self.name)
        else:
            rootdotgit = os.path.relpath(
                os.path.join(self.root_dir, ".git", "modules", self.name),
                start=os.path.join(self.root_dir, self.path),
            )

        if os.path.isdir(os.path.join(self.root_dir, self.path, ".git")):
            with utils.pushd(sprep_repo):
                if os.path.isdir(os.path.join(rootdotgit,".git")):
                    shutil.rmtree(os.path.join(rootdotgit,".git"))
                shutil.move(".git", rootdotgit)
                with open(".git", "w") as f:
                    f.write("gitdir: " + os.path.relpath(rootdotgit))
                infodir = os.path.join(rootdotgit, "info")
                if not os.path.isdir(infodir):
                    os.makedirs(infodir)
                gitsparse = os.path.abspath(os.path.join(infodir, "sparse-checkout"))
            if os.path.isfile(gitsparse):
                self.logger.warning(
                    "submodule {} is already initialized {}".format(self.name, rootdotgit)
                )
                return

            with utils.pushd(sprep_repo):
                if os.path.isfile(self.fxsparse):
                    
                    shutil.copy(self.fxsparse, gitsparse)
                

        # Finally checkout the repo
        sprepo_git.git_operation("fetch", "origin", "--tags")
        status,_ = sprepo_git.git_operation("checkout", self.fxtag)
        if status:
            print(f"Error checking out {self.name:>20} at {self.fxtag}")
        else:
            print(f"Successfully checked out {self.name:>20} at {self.fxtag}")
        rgit.config_set_value('submodule.' + self.name, "active", "true")
        rgit.config_set_value('submodule.' + self.name, "url", self.url)
        rgit.config_set_value('submodule.' + self.name, "path", self.path)

    def update(self):
        """
        Updates the submodule to the latest or specified version.

        This method handles the update process of the submodule, including checking out the submodule into the specified path,
        handling sparse checkouts if configured, and updating the submodule's URL if necessary. It supports both SSH and HTTPS URLs,
        automatically converting SSH URLs to HTTPS to avoid issues for users without SSH keys.

        The update process involves the following steps:
        1. If the submodule is configured for sparse checkout, it performs a sparse checkout.
        2. If the submodule is not already checked out, it clones the submodule using the provided URL.
        3. If a specific tag or hash is provided, it checks out that tag; otherwise, it checks out the latest version.
        4. If the root `.git` is a file (indicating a submodule or a worktree), additional steps are taken to integrate the submodule properly.

        Args:
           None
        Note:
            - SSH URLs are automatically converted to HTTPS to accommodate users without SSH keys.

        Returns:
            None
        """
        git = GitInterface(self.root_dir, self.logger)
        repodir = os.path.join(self.root_dir, self.path)
        self.logger.info("Checkout {} into {}/{}".format(self.name, self.root_dir, self.path))
        # if url is provided update to the new url
        tag = None
        repo_exists = False
        if os.path.exists(os.path.join(repodir, ".git")):
            self.logger.info("Submodule {} already checked out".format(self.name))
            repo_exists = True
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
                    git.git_operation("clone", self.url, self.path)
                    smgit = GitInterface(repodir, self.logger)
                    if not tag:
                        status, tag = smgit.git_operation("describe", "--tags", "--always")
                    smgit.git_operation("checkout", tag)
                    # Now need to move the .git dir to the submodule location
                    rootdotgit = os.path.join(self.root_dir, ".git")
                    if os.path.isfile(rootdotgit):
                        with open(rootdotgit) as f:
                            line = f.readline()
                            if line.startswith("gitdir: "):
                                rootdotgit = line[8:]

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
                git.git_operation("submodule", "add", "--name", self.name, "--", self.url, self.path) 

            if not repo_exists:
                git.git_operation("submodule", "update", "--init", "--", self.path)

            if self.fxtag:        
                smgit = GitInterface(repodir, self.logger)
                newremote = self._add_remote(smgit)
                # Trying to distingush a tag from a hash
                allowed = set(string.digits + 'abcdef') 
                if not set(self.fxtag) <= allowed:
                    # This is a tag
                    tag = f"refs/tags/{self.fxtag}:refs/tags/{self.fxtag}"
                    smgit.git_operation("fetch", newremote, tag)
                smgit.git_operation("checkout", self.fxtag)

            if not os.path.exists(os.path.join(repodir, ".git")):
                utils.fatal_error(
                    f"Failed to checkout {self.name} {repo_exists} {repodir} {self.path}"
                )
                

        if os.path.exists(os.path.join(self.path, ".git")):
            submoddir = os.path.join(self.root_dir, self.path)
            with utils.pushd(submoddir):
                git = GitInterface(submoddir, self.logger)
                # first make sure the url is correct
                newremote = self._add_remote(git)
                status, tags = git.git_operation("tag", "-l")
                fxtag = self.fxtag
                if fxtag and fxtag not in tags:
                    git.git_operation("fetch", newremote, "--tags")
                status, atag = git.git_operation("describe", "--tags", "--always")
                if fxtag and fxtag != atag:
                    try:
                        status, _ = git.git_operation("checkout", fxtag)
                        if not status:
                            print(f"{self.name:>20} updated to {fxtag}")
                    except Exception as error:
                        print(error)
                    

                elif not fxtag:
                    print(f"No fxtag found for submodule {self.name:>20}")
                else:
                    print(f"{self.name:>20} up to date.")


                
        return
