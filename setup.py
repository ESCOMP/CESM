import sys
import os
sys.path.insert(0,os.path.join(os.getenv("CONDA_PREFIX"),"lib","python3.12","site-packages"))

import setuptools
from setuptools import setup, find_packages
from distutils.util import convert_path
from setuptools.command.build_py import build_py
from setuptools.command.install import install
from build_manpages import build_manpages, get_build_py_cmd, get_install_cmd

with open("README.md", "r") as fh:
    long_description = fh.read()

main_ns = {}
ver_path = convert_path('src/fleximod/version.py')
with open(ver_path) as ver_file:
    exec(ver_file.read(), main_ns)

    
setuptools.setup(
    name="git-fleximod",                      # package name
    scripts=["src/git-fleximod"],                     # This is the name of the package
    version=main_ns['__version__'],                        # The initial release version
    author="Jim Edwards",                     # Full name of the author
    maintainer="jedwards4b",
    license="MIT License",
    description="Extended support for git-submodule and git-sparse-checkout",
    long_description=long_description,      # Long description read from the the readme file
    long_description_content_type="text/markdown",
    packages=find_packages(),    # List of all python modules to be installed
    package_dir={'git-fleximod': 'src',
                 'fleximod': 'src/fleximod'},
    package_data={"":['version.txt']},
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],                                      # Information to filter the project on PyPi website
    python_requires='>=3.6',                # Minimum version requirement of the package
#    py_modules=['git-fleximod'],             # Name of the python package
    install_requires=["GitPython"],                     # Install other dependencies if any
    cmdclass={
      'build_manpages': build_manpages,
      # Re-define build_py and install commands so the manual pages
      # are automatically re-generated and installed
      'build_py': get_build_py_cmd(),
      'install': get_install_cmd(install),
  }
)
