from pathlib import Path
import argparse
from git_fleximod import utils

__version__ = "0.9.3"

def find_root_dir(filename=".gitmodules"):
    """ finds the highest directory in tree
    which contains a file called filename """
    try:
        root = utils.execute_subprocess(["git","rev-parse", "--show-toplevel"],
                                        output_to_caller=True ).rstrip()
    except:
        d = Path.cwd()
        root = Path(d.root)
        dirlist = []
        dl = d
        while dl != root:
            dirlist.append(dl)
            dl = dl.parent
        dirlist.append(root)
        dirlist.reverse()

        for dl in dirlist:
            attempt = dl / filename
            if attempt.is_file():
                return str(dl)
        return None
    return Path(root)

def get_parser():
    description = """
    %(prog)s manages checking out groups of gitsubmodules with additional support for Earth System Models
    """
    parser = argparse.ArgumentParser(
        description=description, formatter_class=argparse.RawDescriptionHelpFormatter
    )

    #
    # user options
    #
    choices = ["update", "status", "test"]
    parser.add_argument(
        "action",
        choices=choices,
        default="update",
        help=f"Subcommand of git-fleximod, choices are {choices[:-1]}",
    )

    parser.add_argument(
        "components",
        nargs="*",
        help="Specific component(s) to checkout. By default, "
        "all required submodules are checked out.",
    )

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
        "-x",
        "--exclude",
        nargs="*",
        help="Component(s) listed in the gitmodules file which should be ignored.",
    )
    parser.add_argument(
        "-f",
        "--force",
        action="store_true",
        default=False,
        help="Override cautions and update or checkout over locally modified repository.",
    )

    parser.add_argument(
        "-o",
        "--optional",
        action="store_true",
        default=False,
        help="By default only the required submodules "
        "are checked out. This flag will also checkout the "
        "optional submodules relative to the toplevel directory.",
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
        "-V",
        "--version",
        action="version",
        version=f"%(prog)s {__version__}",
        help="Print version and exit.",
    )

    #
    # developer options
    #
    parser.add_argument(
        "--backtrace",
        action="store_true",
        help="DEVELOPER: show exception backtraces as extra " "debugging output",
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
