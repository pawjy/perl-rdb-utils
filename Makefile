all: 

## ------ Setup ------

WGET = wget
GIT = git

Makefile-setupenv: Makefile.setupenv
	$(MAKE) --makefile Makefile.setupenv setupenv-update \
	    SETUPENV_MIN_REVISION=20121001

Makefile.setupenv:
	$(WGET) -O $@ https://raw.github.com/wakaba/perl-setupenv/master/Makefile.setupenv

generatepm: %: Makefile-setupenv
	$(MAKE) --makefile Makefile.setupenv $@

pmb-update: pmbp-update
pmb-install: pmbp-install
lperl: pmbp-install
lprove: pmbp-install
local-perl: pmbp-install

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(WGET) -O $@ https://github.com/wakaba/perl-setupenv/raw/master/bin/pmbp.pl

pmbp-update: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --update

pmbp-install: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --install \
	    --create-perl-command-shortcut=perl \
	    --create-perl-command-shortcut=prove

git-submodules:
	$(GIT) submodule update --init

deps: git-submodules pmbp-install

## ------ Tests ------

PROVE = ./prove

test: test-deps test-main

test-deps: deps

test-main:
	$(PROVE) t/*.t

## ------ Packaging ------

dist: always
	mkdir -p dist
	generate-pm-package config/dist/dbix-showsql.pi dist
	generate-pm-package config/dist/test-mysql-createdatabase.pi dist
	generate-pm-package config/dist/anyevent-dbi-hashref.pi dist

always:
