.PHONY: all clean install build
all: build doc

NAME=forkexec
J=4

BINDIR ?= /usr/bin
SBINDIR ?= /usr/sbin
ETCDIR ?= /etc
DESTDIR ?= /

export OCAMLRUNPARAM=b

setup.bin: setup.ml
	@ocamlopt.opt -o $@ $< || ocamlopt -o $@ $< || ocamlc -o $@ $<
	@rm -f setup.cmx setup.cmi setup.o setup.cmo

setup.data: setup.bin
	@./setup.bin -configure

build: setup.data setup.bin version.ml
	@./setup.bin -build -j $(J)
	mv fe_main.native xapi-fe
	./xapi-fe --help=groff > xapi-fe.1
	mv fe_cli.native xapi-fe-cli

version.ml: VERSION
	echo "let version = \"$(shell cat VERSION)\"" > lib/version.ml

doc: setup.data setup.bin
	@./setup.bin -doc -j $(J)

install: setup.bin
	@./setup.bin -install
	mkdir -p $(DESTDIR)/$(ETCDIR)/init.d
	install ./src/init.d-fe $(DESTDIR)/$(ETCDIR)/init.d/xapi-fe
	mkdir -p $(DESTDIR)/$(SBINDIR)
	install ./xapi-fe $(DESTDIR)/$(SBINDIR)/xapi-fe
	mkdir -p $(DESTDIR)/$(MANDIR)
	install ./xapi-fe.1 $(DESTDIR)/$(MANDIR)/xapi-fe.1
	install ./xapi-fe-cli $(DESTDIR)/$(BINDIR)/xapi-fe-cli

test: setup.bin build
	@./setup.bin -test

reinstall: setup.bin
	@ocamlfind remove $(NAME) || true
	@./setup.bin -reinstall
	install ./src/init.d-fe $(DESTDIR)/$(ETCDIR)/init.d/xapi-fe
	install ./xapi-fe $(DESTDIR)/$(SBINDIR)/xapi-fe
	install ./xapi-fe.1 $(DESTDIR)/$(MANDIR)/xapi-fe.1
	install ./xapi-fe-cli $(DESTDIR)/$(BINDIR)/xapi-fe-cli

uninstall:
	@ocamlfind remove $(NAME) || true
	rm -f $(DESTDIR)/$(ETCDIR)/init.d/xapi-fe
	rm -f $(DESTDIR)/$(SBINDIR)/xapi-fe
	rm -f $(DESTDIR)/$(MANDIR)/xapi-fe.1
	rm -f $(DESTDIR)/$(BINDIR)/xapi-fe-cli

clean:
	@ocamlbuild -clean
	@rm -f setup.data setup.log setup.bin
