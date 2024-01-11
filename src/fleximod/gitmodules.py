import os
import shutil
from configparser import ConfigParser
from fleximod.lstripreader import LstripReader

class GitModules(ConfigParser):
    def __init__(
        self,
        logger,
        confpath=os.getcwd(),
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
        self.logger.debug("Creating a GitModules object {} {} {} {}".format(confpath,conffile,includelist,excludelist))
        ConfigParser.__init__(self)
        self.conf_file = os.path.join(confpath, conffile)
        # first create a backup of this file to be restored on deletion of the object
        shutil.copy(self.conf_file, self.conf_file+".save")
        self.read_file(LstripReader(self.conf_file), source=conffile)
        self.includelist = includelist
        self.excludelist = excludelist

    def set(self, name, option, value):
        """
        Sets a configuration value for a specific submodule:
        Ensures the appropriate section exists for the submodule.
        Calls the parent class's set method to store the value.
        """
        self.logger.debug("set called {} {} {}".format(name,option,value))
        section = f'submodule "{name}"'
        if not self.has_section(section):
            self.add_section(section)
        ConfigParser.set(self, section, option, str(value))

    # pylint: disable=redefined-builtin, arguments-differ
    def get(self, name, option, raw=False, vars=None, fallback=None):
        """
        Retrieves a configuration value for a specific submodule:
        Uses the parent class's get method to access the value.
        Handles potential errors if the section or option doesn't exist.
        """
        self.logger.debug("get called {} {}".format(name,option))
        section = f'submodule "{name}"'
        try:
            return ConfigParser.get(
                self, section, option, raw=raw, vars=vars, fallback=fallback
            )
        except ConfigParser.NoOptionError:
            return None

    def save(self):
        print("Called gitmodules save, not expected")
        #        self.write(open(self.conf_file, "w"))

    def __del__(self):
        self.logger.debug("Destroying GitModules object")
        shutil.move(self.conf_file+".save", self.conf_file)
            
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
