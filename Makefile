MAKE_IN_SRC := $(MAKE) -C SRC

.PHONY: all
all:
	$(MAKE_IN_SRC) all

%:
	$(MAKE_IN_SRC) $@
