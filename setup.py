import setuptools
import os
from setuptools import setup, find_packages
from distutils.util import convert_path

with open("README.md", "r") as fh:
    long_description = fh.read()

main_ns = {}
ver_path = convert_path('src/fleximod/version.py')
with open(ver_path) as ver_file:
    exec(ver_file.read(), main_ns)

    
setuptools.setup(
    scripts=["src/git-fleximod"],                     # This is the name of the package
    version=main_ns['__version__'],                        # The initial release version
    author="Jim Edwards",                     # Full name of the author
    maintainer="jedwards4b",
    license="MIT License",
    description="Extended support for git-submodule and git-sparse-checkout",
    long_description=long_description,      # Long description read from the the readme file
    long_description_content_type="text/markdown",
    packages=['fleximod'],    # List of all python modules to be installed
    package_dir={'fleximod': 'src/fleximod'},
    package_data={"":['version.txt']},
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],                                      # Information to filter the project on PyPi website
    python_requires='>=3.6',                # Minimum version requirement of the package
#    py_modules=['git-fleximod'],             # Name of the python package
    install_requires=["GitPython"]                     # Install other dependencies if any
)
