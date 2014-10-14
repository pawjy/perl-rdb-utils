#!/bin/sh
echo "1..1"
(`dirname $0`/../perl -c `dirname $0`/../bin/generate-certs-for-tests.pl && echo "ok 1") || echo "not ok 1"
