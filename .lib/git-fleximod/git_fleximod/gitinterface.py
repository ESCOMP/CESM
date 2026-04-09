# git_fleximod/gitinterface.py
import sys
from . import utils
from pathlib import Path
import asyncio


class GitInterface:
    def __init__(self, repo_path, logger):
        if isinstance(repo_path, str):
            self.repo_path = Path(repo_path).resolve()
        elif isinstance(repo_path, Path):
            self.repo_path = repo_path.resolve()
        else:
            raise TypeError("repo_path must be a str or Path object")
        if logger is not None:
            self.logger = logger
        else:
            import logging

            self.logger = logging.getLogger(__name__)
            if not self.logger.hasHandlers():
                handler = logging.StreamHandler()
                formatter = logging.Formatter(
                    "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
                )
                handler.setFormatter(formatter)
                self.logger.addHandler(handler)
                self.logger.setLevel(logging.DEBUG)
        self.logger.debug("Initialize GitInterface for {}".format(repo_path))
        try:
            import git

            self._use_module = True
            try:
                self.repo = git.Repo(str(self.repo_path))  # Initialize GitPython repo
            except git.exc.InvalidGitRepositoryError:
                self.git = git
                self._init_git_repo()
            msg = "Using GitPython interface to git"
        except ImportError:
            self._use_module = False
            if not (self.repo_path / ".git").exists():
                self._init_git_repo()
            msg = "Using shell interface to git"
        self.logger.info(msg)

    def _git_command(self, operation, *args):
        """
        Internal: Build git command or call GitPython.
        >>> gi = GitInterface('.', None)
        >>> isinstance(gi._git_command('status'), list) or isinstance(gi._git_command('status'), str)
        True
        """
        self.logger.info(operation)
        if self._use_module and operation != "submodule":
            try:
                return getattr(self.repo.git, operation)(*args)
            except Exception as e:
                sys.exit(e)
        else:
            return ["git", "-C", str(self.repo_path), operation] + list(args)

    def _init_git_repo(self):
        if self._use_module:
            self.repo = self.git.Repo.init(str(self.repo_path))
        else:
            command = ("git", "-C", str(self.repo_path), "init")
            utils.execute_subprocess(command)

    def _git_operation_command(self, operation, args):
        newargs = []
        for a in args:
            # Do not use ssh interface
            if isinstance(a, str):
                a = a.replace("git@github.com:", "https://github.com/")
            newargs.append(a)

        return self._git_command(operation, *newargs)

    # pylint: disable=unused-argument
    def git_operation(self, operation, *args, **kwargs):
        """
        Run a git operation and return status and output.
        >>> gi = GitInterface('.', None)
        >>> status, output = gi.git_operation('status')
        >>> isinstance(status, int)
        True
        >>> isinstance(output, str)
        True
        """
        newargs = []
        for a in args:
            # Do not use ssh interface
            if isinstance(a, str):
                a = a.replace("git@github.com:", "https://github.com/")
            newargs.append(a)

        command = self._git_command(operation, *newargs)
        if isinstance(command, list):
            try:
                status, output = utils.execute_subprocess(
                    command, status_to_caller=True, output_to_caller=True
                )
                return status, output.rstrip()
            except Exception as e:
                sys.exit(e)
        else:
            return 0, command

    # pylint: disable=unused-argument
    async def git_operation_async(self, operation, *args, **kwargs):
        """
        Asynchronously run a git operation.
        (Doc test not run: async context)
        """
        command = self._git_operation_command(operation, args)
        if isinstance(command, list):
            try:
                process = await asyncio.create_subprocess_exec(
                    *command,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                )
                stdout, stderr = await process.communicate()
                status = process.returncode
                output = stdout.decode().strip() if stdout else stderr.decode().strip()
                return status, output
            except Exception as e:
                sys.exit(e)
        else:
            return 0, command

    def config_get_value(self, section, name):
        """
        Get a git config value.
        >>> gi = GitInterface('.', None)
        >>> gi.config_get_value('user', 'name') is None or isinstance(gi.config_get_value('user', 'name'), str)
        True
        """
        if self._use_module:
            config = self.repo.config_reader()
            try:
                val = config.get_value(section, name)
            except:
                val = None
            return val
        else:
            cmd = (
                "git",
                "-C",
                str(self.repo_path),
                "config",
                "--get",
                f"{section}.{name}",
            )
            output = utils.execute_subprocess(cmd, output_to_caller=True)
            return output.strip()

    def config_set_value(self, section, name, value):
        """
        Set a git config value.
        (Doc test not run: modifies config)
        """
        if self._use_module:
            with self.repo.config_writer() as writer:
                if "." in section:
                    section = section.replace(".", ' "') + '"'
                writer.set_value(section, name, value)
            writer.release()  # Ensure changes are saved
        else:
            cmd = (
                "git",
                "-C",
                str(self.repo_path),
                "config",
                f"{section}.{name}",
                value,
            )
            self.logger.info(cmd)
            utils.execute_subprocess(cmd, output_to_caller=True)
