all:

dist: always
	mkdir -p dist
	generate-pm-package config/dist/dbix-showsql.pi dist
	generate-pm-package config/dist/test-mysql-createdatabase.pi dist
	generate-pm-package config/dist/anyevent-dbi-hashref.pi dist

test: safetest

safetest:
	prove t/*.t

always:

## License: Public Domain.
