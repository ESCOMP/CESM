import os
from configparser import ConfigParser

from modules.lstripreader import LstripReader


class GitModules(ConfigParser.ConfigParser):
    def __init__(
        self,
        confpath=os.getcwd(),
        conffile=".gitmodules",
        includelist=None,
        excludelist=None,
    ):
        ConfigParser.ConfigParser.__init__(self)
        self.read_file(LstripReader(confpath), source=conffile)
        self.conf_file = os.path.join(confpath, conffile)
        self.includelist = includelist
        self.excludelist = excludelist

    def set(self, name, option, value):
        section = f'submodule "{name}"'
        if not self.has_section(section):
            self.add_section(section)
        ConfigParser.ConfigParser.set(self, section, option, str(value))

    def get(self, name, option):
        section = f'submodule "{name}"'
        try:
            return ConfigParser.ConfigParser.get(self, section, option)
        except ConfigParser.NoOptionError:
            return None

    def save(self):
        self.write(open(self.conf_file, "w"))

    def __del__(self):
        self.save()

    def sections(self):
        names = []
        for section in ConfigParser.ConfigParser.sections(self):
            name = section[11:-1]
            if self.includelist and name not in self.includelist:
                continue
            if self.excludelist and name in self.excludelist:
                continue
            names.append(name)
        return names

    def items(self, name):
        section = f'submodule "{name}"'
        return ConfigParser.ConfigParser.items(section)
