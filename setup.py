import setuptools
import os

with open("README.md", "r") as fh:
    long_description = fh.read()
with open("version.txt", "r") as fh:
    version = fh.read()
    cwd = os.getcwd()
setuptools.setup(
    name="git-fleximod",                     # This is the name of the package
    version=version,                        # The initial release version
    author="Jim Edwards",                     # Full name of the author
    description="Extended support for git-submodule and git-sparse-checkout",
    long_description=long_description,      # Long description read from the the readme file
    long_description_content_type="text/markdown",
    packages=setuptools.find_packages(),    # List of all python modules to be installed
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],                                      # Information to filter the project on PyPi website
    python_requires='>=3.6',                # Minimum version requirement of the package
    py_modules=['git-fleximod'],             # Name of the python package
    package_dir={'git-fleximod':'.'},     # Directory of the source code of the package
    install_requires=[]                     # Install other dependencies if any
)
