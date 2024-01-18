import os
import logging
from fleximod import utils

class GitInterface:
    def __init__(self, repo_path, logger):
        logger.debug("Initialize GitInterface for {}".format(repo_path))
        self.repo_path = repo_path
        self.logger = logger
        try:
            import git
            self._use_module = True
            try:
                self.repo = git.Repo(repo_path)  # Initialize GitPython repo
            except git.exc.InvalidGitRepositoryError:
                self.git = git
                self._init_git_repo()
            msg = "Using GitPython interface to git"
        except ImportError:
            self._use_module = False
            if not os.path.exists(os.path.join(repo_path,".git")):
                self._init_git_repo()
            msg = "Using shell interface to git"
        self.logger.info(msg)
                
    def _git_command(self, operation, *args):
        self.logger.info(operation)
        if self._use_module and operation != "submodule":
            return getattr(self.repo.git, operation)(*args)
        else:
            return ["git", "-C",self.repo_path, operation] + list(args)

    def _init_git_repo(self):
        if self._use_module:
            self.repo = self.git.Repo.init(self.repo_path)
        else:
            command = ("git", "-C", self.repo_path, "init")
            utils.execute_subprocess(command)


    def git_operation(self, operation, *args, **kwargs):
        command = self._git_command(operation, *args)
        self.logger.info(command)
        if isinstance(command, list):
            return utils.execute_subprocess(command, output_to_caller=True)
        else:
            return command

    def config_get_value(self, section, name):
        if self._use_module:
            config = self.repo.config_reader()
            return config.get_value(section, name)
        else:
            cmd = ("git","-C",self.repo_path,"config", "--get", f"{section}.{name}")
            output = utils.execute_subprocess(cmd, output_to_caller=True)
            return output.strip()

    def config_set_value(self, section, name, value):
        if self._use_module:
            with self.repo.config_writer() as writer:
                writer.set_value(section, name, value)
            writer.release()  # Ensure changes are saved
        else:
            cmd = ("git","-C",self.repo_path,"config", f"{section}.{name}", value)
            self.logger.info(cmd)
            utils.execute_subprocess(cmd, output_to_caller=True)
