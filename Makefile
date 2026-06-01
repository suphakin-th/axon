VERSION  := 1.0.0
PREFIX   := /usr/local
BINDIR   := $(PREFIX)/bin
SHAREDIR := $(PREFIX)/share/axon

.PHONY: install uninstall help

install:
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 bin/axon $(DESTDIR)$(BINDIR)/axon
	@echo "axon installed to $(DESTDIR)$(BINDIR)/axon"

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/axon
	@echo "axon removed"

help:
	@echo "Targets:"
	@echo "  make install       install axon to $(BINDIR)"
	@echo "  make uninstall     remove axon from $(BINDIR)"
	@echo "  PREFIX=/custom     override install prefix"
