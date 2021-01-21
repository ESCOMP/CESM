
SHELL = /bin/sh

SUBDIRS = simple climate_concur1 climate_sequen1

# TARGETS
subdirs:
	@for dir in $(SUBDIRS); do \
	  cd $$dir;                \
	  $(MAKE);                 \
	  cd ..;                   \
	done

clean:
	@for dir in $(SUBDIRS); do \
	  cd $$dir;                \
	  $(MAKE) clean;           \
	  cd ..;                   \
	done

