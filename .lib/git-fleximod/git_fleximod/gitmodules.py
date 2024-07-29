import shutil, os
from pathlib import Path
from configparser import RawConfigParser, ConfigParser
from .lstripreader import LstripReader


class GitModules(RawConfigParser):
    def __init__(
        self,
        logger,
        confpath=Path.cwd(),
        conffile=".gitmodules",
        includelist=None,
        excludelist=None,
    ):
        """
        confpath: Path to the directory containing the .gitmodules file (defaults to the current working directory).
        conffile: Name of the configuration file (defaults to .gitmodules).
        includelist: Optional list of submodules to include.
        excludelist: Optional list of submodules to exclude.
        """
        self.logger = logger
        self.logger.debug(
            "Creating a GitModules object {} {} {} {}".format(
                confpath, conffile, includelist, excludelist
            )
        )
        super().__init__()
        self.conf_file = (Path(confpath) / Path(conffile))
        if self.conf_file.exists():
            self.read_file(LstripReader(str(self.conf_file)), source=conffile)
        self.includelist = includelist
        self.excludelist = excludelist
        self.isdirty = False
        
    def reload(self):
        self.clear()
        if self.conf_file.exists():
            self.read_file(LstripReader(str(self.conf_file)), source=self.conf_file)

        
    def set(self, name, option, value):
        """
        Sets a configuration value for a specific submodule:
        Ensures the appropriate section exists for the submodule.
        Calls the parent class's set method to store the value.
        """
        self.isdirty = True
        self.logger.debug("set called {} {} {}".format(name, option, value))
        section = f'submodule "{name}"'
        if not self.has_section(section):
            self.add_section(section)
        super().set(section, option, str(value))

    # pylint: disable=redefined-builtin, arguments-differ
    def get(self, name, option, raw=False, vars=None, fallback=None):
        """
        Retrieves a configuration value for a specific submodule:
        Uses the parent class's get method to access the value.
        Handles potential errors if the section or option doesn't exist.
        """
        self.logger.debug("git get called {} {}".format(name, option))
        section = f'submodule "{name}"'
        try:
            return ConfigParser.get(
                self, section, option, raw=raw, vars=vars, fallback=fallback
            )
        except ConfigParser.NoOptionError:
            return None

    def save(self):
        if self.isdirty:
            self.logger.info("Writing {}".format(self.conf_file))
            with open(self.conf_file, "w") as fd:
                self.write(fd)
        self.isdirty = False
        
    def __del__(self):
        self.save()

    def sections(self):
        """Strip the submodule part out of section and just use the name"""
        self.logger.debug("calling GitModules sections iterator")
        names = []
        for section in ConfigParser.sections(self):
            name = section[11:-1]
            if self.includelist and name not in self.includelist:
                continue
            if self.excludelist and name in self.excludelist:
                continue
            names.append(name)
        return names

    def items(self, name, raw=False, vars=None):
        self.logger.debug("calling GitModules items for {}".format(name))
        section = f'submodule "{name}"'
        return ConfigParser.items(section, raw=raw, vars=vars)
