all:

dist: always
	mkdir -p dist
	generate-pm-package config/dist/dbix-showsql.pi dist

test: safetest

safetest:
	prove t/*.t

always:

## License: Public Domain.
