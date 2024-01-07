# git-fleximod

Flexible Submodule Management for Git

## Overview

Git-fleximod is a Python-based tool that extends Git's submodule capabilities, offering additional features for managing submodules in a more flexible and efficient way.

## Installation

#TODO    Install using pip:
#        pip install git-fleximod
  If you choose to locate git-fleximod in your path you can access it via command: git fleximod

## Usage

    Basic Usage:
        git fleximod <command> [options]
    Available Commands:
        install: Install submodules according to configuration.
        status: Display the status of submodules.
        update: Update submodules to the tag indicated in .gitmodules variable fxtag.
    Additional Options:
        See git fleximod --help for more details.

## Supported .gitmodules Variables

    fxtag: Specify a specific tag or branch to checkout for a submodule.
    fxrequired: Mark a submodule's checkout behavior, with allowed values:
      - T:T: Top-level and required (checked out only when this is the Toplevel module).
      - T:F: Top-level and optional (checked out with --optional flag if this is the Toplevel module).
      - I:T: Internal and required (always checked out).
      - I:F: Internal and optional (checked out with --optional flag).
    fxsparse: Enable sparse checkout for a submodule, pointing to a file containing sparse checkout paths.

## Sparse Checkouts

    To enable sparse checkout for a submodule, set the fxsparse variable
    in the .gitmodules file to the path of a file containing the desired
    sparse checkout paths. Git-fleximod will automatically configure
    sparse checkout based on this file when applicable commands are run.
    See [git-sparse-checkout](https://git-scm.com/docs/git-sparse-checkout#_internalsfull_pattern_set) for details on the format of this file.

## Examples

Here are some common usage examples:

Installing submodules, including optional ones:
```bash
  git fleximod install --optional
```

Updating a specific submodule to the fxtag indicated in .gitmodules:

```bash
    git fleximod update submodule-name
```
Example .gitmodules entry:
```ini, toml
    [submodule "cosp2"]
        path = src/physics/cosp2/src
        url = https://github.com/CFMIP/COSPv2.0
        fxsparse = ../.cosp_sparse_checkout
        fxtag = v2.1.4cesm
```
Explanation:

This entry indicates that the submodule named cosp2 at tag v2.1.4cesm
should be checked out into the directory src/physics/cosp2/src
relative to the .gitmodules directory.  It should be checked out from
the URL https://github.com/CFMIP/COSPv2.0 and use sparse checkout as
described in the file ../.cosp_sparse_checkout relative to the path
directory.

Additional example:
```ini, toml
    [submodule "cime"]
        path = cime
        url = https://github.com/jedwards4b/cime
        fxrequired = T:T
        fxtag = cime6.0.198_rme01
```

Explanation:

This entry indicates that the submodule cime should be checked out
into a directory named cime at tag cime6.0.198_rme01 from the URL
https://github.com/jedwards4b/cime.  This should only be done if
the .gitmodules file is at the top level of the repository clone.

## Contributing

We welcome contributions! Please see the CONTRIBUTING.md file for guidelines.

## License

Git-fleximod is released under the MIT License.
