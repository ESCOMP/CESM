The documentation source is stored with the CESM master code base. However, 
the built html files are stored separately in the orphan gh-pages branch
and can be viewed from a browser at URL:

http://escomp.github.io/cesm

The easiest way to build the documentation is to use a Docker image that
contains the necessary dependencies together with the doc-builder helper
tool.

To set this up initially on a given machine:
1. Install Docker
2. Launch Docker's desktop application and run: `docker pull escomp/base` (you should also redo this step if you haven't updated this docker image in a while)
3. Obtain the doc-builder helper tool: `git clone git@github.com:ESMCI/doc-builder.git`
4. Ensure that the `build_docs` command from the `doc-builder` repository is in your path (by adding the directory to your path or creating a symbolic link to it somewhere in your path

Then, to build the documentation:
1. Clone the CESM repository and checkout the gh-pages branch: `git clone -b gh-pages git@github.com:ESCOMP/CESM.git /PATH/TO/cesm-gh-pages` (replacing `/PATH/TO` with the desired path). **Note that both your main CESM clone and this cesm-gh-pages clone must reside somewhere within your home directory for the Docker-based workflow to work properly.**
2. From this `doc` directory, run a command like the following: `build_docs -d -c -r /PATH/TO/cesm-gh-pages -v cesm2.1`.
   - The `-d` argument tells `build_docs` to use Docker
   - The `-c` argument first runs `make clean` (which is often unnecessary, but doesn't hurt for this quick documentation build)
   - The `-r` argument gives the path to the root of the documentation repository; replace this with the path to your `cesm-gh-pages` clone
   - The `-v` argument gives the version you are building; replace this with one of the versions in the `versions` directory of the `cesm-gh-pages` clone
3. From the `cesm-gh-pages` clone, run `git add .`, `git commit` and `git push` to publish the new documentation. This will automatically update the documentation at http://escomp.github.io/cesm (but it may take a few minutes for the new version to appear).

For more details on working with sphinx-based documentation, including how to add new versions, see:
- https://github.com/ESCOMP/CTSM/wiki/Directions-for-editing-CLM-documentation-on-github-and-sphinx
- https://github.com/ESMCI/cime/wiki/Working-with-Sphinx-and-reStructuredText
