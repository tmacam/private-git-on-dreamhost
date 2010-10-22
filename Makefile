
TARGETS := README.html
RST2HTML := /Users/macambira/bin/rst2html.py
RST2HTMLOPT := --input-encoding=utf-8 --output-encoding=utf-8

all: $(TARGETS)


%.html: %.rst
	$(RST2HTML) $(RST2HTMLOPT) $< $@

clean:
	-rm -fv $(TARGETS)

.PHONY: clean all
