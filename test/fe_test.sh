#!/bin/sh

../src/fe_main.exe &
MAIN=$!
cleanup () {
    kill $MAIN
}
trap cleanup EXIT
for _ in $(seq 1 10); do
	test -S /var/xapi/forker/main || sleep 1
done
echo "" | ./fe_test.exe 16
