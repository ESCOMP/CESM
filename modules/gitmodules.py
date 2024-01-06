import os
from configparser import ConfigParser

from modules.lstripreader import LstripReader


class GitModules(ConfigParser):
    def __init__(
        self,
        confpath=os.getcwd(),
        conffile=".gitmodules",
        includelist=None,
        excludelist=None,
    ):
        ConfigParser.__init__(self)
        self.conf_file = os.path.join(confpath, conffile)
        self.read_file(LstripReader(self.conf_file), source=conffile)
        self.includelist = includelist
        self.excludelist = excludelist

    def set(self, name, option, value):
        section = f'submodule "{name}"'
        if not self.has_section(section):
            self.add_section(section)
        ConfigParser.set(self, section, option, str(value))

    # pylint: disable=redefined-builtin, arguments-differ
    def get(self, name, option, raw=False, vars=None, fallback=None):
        section = f'submodule "{name}"'
        try:
            return ConfigParser.get(
                self, section, option, raw=raw, vars=vars, fallback=fallback
            )
        except ConfigParser.NoOptionError:
            return None

    def save(self):
        self.write(open(self.conf_file, "w"))

    def sections(self):
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
        section = f'submodule "{name}"'
        return ConfigParser.items(section, raw=raw, vars=vars)
