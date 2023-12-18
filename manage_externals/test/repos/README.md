Git and svn repositories for testing git and svn-related behavior.  For usage and terminology notes, see test/test_sys_checkout.py.

For git repos: To list files and view file contents at HEAD:
```
cd <repo_dir>
git ls-tree --full-tree -r --name-only HEAD
git cat-file -p HEAD:<filename>
```

File contents at a glance:
```
container.git/
  readme.txt

simple-ext.git/
  (has branches: feature2, feature3)
  (has tags: tag1, tag2)
  readme.txt
  simple_subdir/subdir_file.txt

simple-ext-fork.git/
  (has tags: abandoned-feature, forked-feature-v1, tag1)
  (has branch: feature2)
  readme.txt

mixed-cont-ext.git/
  (has branch: new-feature)
  readme.txt
  sub-externals.cfg ('simp_branch' section refers to 'feature2' branch in simple-ext.git/ repo)

error/
   (no git repo here, just a readme.txt in the clear)
```
