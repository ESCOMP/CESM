# git-fleximod

Flexible Submodule Management for Git

## Overview

Git-fleximod is a Python-based tool that extends Git's submodule capabilities, offering additional features for managing submodules in a more flexible and efficient way.

## Installation

    Install using pip:
        pip install git-fleximod

## Usage

    Basic Usage:
        git fleximod <command> [options]
    Available Commands:
        install: Install submodules according to configuration.
        status: Display the status of submodules.
        update: Update submodules to their latest commits.
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

## Examples

    Installing submodules with optional ones: git fleximod install --optional
    Checking out a specific tag for a submodule: git fleximod update --fxtag=v1.2.3 submodule-name

## Contributing

We welcome contributions! Please see the CONTRIBUTING.md file for guidelines.

## License

Git-fleximod is released under the MIT License.
