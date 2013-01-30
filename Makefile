
TARGETS := README.html
RST2HTML := $(shell which rst2html)
RST2HTMLOPT := --input-encoding=utf-8 --output-encoding=utf-8
	#--initial-header-level=3

all: $(TARGETS) README.rst

# GitHub
README.rst : README-real.rst
	awk -f parse_readme_includes.awk $< > .tmp.$@
	mv -fv .tmp.$@ $@

%.html: %.rst
	$(RST2HTML) $(RST2HTMLOPT) $< $@

clean:
	-rm -fv $(TARGETS)

.PHONY: clean all
