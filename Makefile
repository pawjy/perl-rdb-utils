all: 

## ------ Setup ------

WGET = wget
GIT = git
PERL = perl
PERL_VERSION = 5.16.1
PERL_PATH = $(abspath local/perlbrew/perls/perl-$(PERL_VERSION)/bin)
PERL_ENV = PATH="$(abspath local/perlbrew/perls/perl-$(PERL_VERSION)/bin):$(abspath local/perl-$(PERL_VERSION)/pm/bin):$(PATH)" PERL5LIB="$(shell cat config/perl/libs.txt)"

PMB_PMTAR_REPO_URL =
PMB_PMPP_REPO_URL = 

Makefile-setupenv: Makefile.setupenv
	$(MAKE) --makefile Makefile.setupenv setupenv-update \
	    SETUPENV_MIN_REVISION=20120337

Makefile.setupenv:
	$(WGET) -O $@ https://raw.github.com/wakaba/perl-setupenv/master/Makefile.setupenv

lperl lprove perl-version perl-exec \
local-submodules generatepm: %: Makefile-setupenv
	$(MAKE) --makefile Makefile.setupenv $@ \
	    PMB_PMTAR_REPO_URL=$(PMB_PMTAR_REPO_URL) \
	    PMB_PMPP_REPO_URL=$(PMB_PMPP_REPO_URL)

pmb-update: pmbp-update
pmb-install: pmbp-install

local/bin/pmbp.pl: always
	mkdir -p local/bin
	$(WGET) -O $@ https://github.com/wakaba/perl-setupenv/raw/master/bin/pmbp.pl

local-perl: local/bin/pmbp.pl
	$(PERL_ENV) $(PERL) local/bin/pmbp.pl --perl-version $(PERL_VERSION) --install-perl

pmbp-update: local/bin/pmbp.pl
	$(PERL_ENV) $(PERL) local/bin/pmbp.pl --update

pmbp-install: local/bin/pmbp.pl
	$(PERL_ENV) $(PERL) local/bin/pmbp.pl --install

git-submodules:
	$(GIT) submodule update --init

deps: git-submodules pmb-install

## ------ Tests ------

PROVE = prove

test: test-deps test-main

test-deps: local-submodules deps

test-main:
	$(PERL_ENV) $(PROVE) t/*.t

## ------ Packaging ------

dist: always
	mkdir -p dist
	generate-pm-package config/dist/dbix-showsql.pi dist
	generate-pm-package config/dist/test-mysql-createdatabase.pi dist
	generate-pm-package config/dist/anyevent-dbi-hashref.pi dist

always:
