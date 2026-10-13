#!/bin/sh
# Apply CoA Custom world SQL in numeric filename order.
# Usage: sh apply.sh /path/to/my.cnf
set -e
if [ -z "$1" ]; then
  echo "usage: sh apply.sh /path/to/my.cnf" >&2
  exit 1
fi
cd "$(dirname "$0")"
for sql in $(ls -1 *.sql | sort -t_ -k1,1n); do
  echo "  $sql"
  mysql --defaults-file="$1" --database=acore_world < "$sql"
done
