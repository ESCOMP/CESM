
SHELL = /bin/sh

include Makefile.conf

SUBDIRS = $(MPISERPATH) $(MPEUPATH) $(MCTPATH)

# TARGETS
subdirs:
	@set -e; for dir in $(SUBDIRS); do \
	  cd $$dir;                \
	  $(MAKE);                 \
	  cd $(abs_top_builddir);  \
	done

clean:
	@set -e; for dir in $(SUBDIRS); do \
	  cd $$dir;                \
	  $(MAKE) clean;           \
	  cd $(abs_top_builddir);  \
	done

install: subdirs
	@set -e; for dir in $(SUBDIRS); do \
	  cd $$dir;                \
	  $(MAKE) install;         \
	  cd $(abs_top_builddir);  \
	done

examples: subdirs
	@cd $(EXAMPLEPATH) && $(MAKE)


