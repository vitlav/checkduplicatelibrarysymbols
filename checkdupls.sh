#!/bin/sh

fatal()
{
    echo "$@" >&2
    exit 1
}

PRG="$(which "$1" 2>/dev/null)"
[ -n "$PRG" ] || PRG="$1"
PRG="$(realpath "$PRG")"
[ -r "$PRG" ] || fatal "Run with prog or lib as arg, please."

file "$PRG" | grep -q ELF || fatal "$PRG is not ELF executable"
file "$PRG" | grep -q "statically linked" && fatal "$PRG is a statically linked binary, skipping"

# template for temp file names
OB=checkdupls

echo "Checking $PRG ..."

echo -n "Read all libs... "
ldd -r $PRG | grep "not found" > $OB.libs.notfound
ldd -r $PRG | grep "undefined symbol" > $OB.libs.undefined
ldd -r $PRG | grep -v "not found" | grep -v "undefined symbol" | sed -e "s|.*=> ||g" | sed -e "s| .*||g" > $OB.libs
cat $OB.libs | xargs readlink -f > $OB.libs.u
wc -l < $OB.libs.u

if [ -s "$OB.libs.notfound" ] ; then
    echo "Not found libs:"
    cat $OB.libs.notfound
fi

if [ -s "$OB.libs.undefined" ] ; then
    echo "There is $(wc -l < $OB.libs.undefined) undefined symbols (see $OB.libs.undefined or ldd -r $PRG output for details)"
fi

echo -n "Get all symbols... "
rm -f $OB.out $OB.out.libs
for i in $(cat $OB.libs.u | grep -v "linux-gate.so.1" | grep -v "/libc-.*.so" | grep -v "linux-vdso.so" | grep -v "libwayland") ; do
	#$OBjdump -p $PRG | grep NEEDED
	nm -D $i | grep " T " | sed -e "s|.* T ||g" | uniq | tee -a $OB.out | sed -e "s|$| $i|g" >> $OB.out.libs
done
wc -l < $OB.out.libs

echo -n "Get all non uniq symbols... "
sort < $OB.out | uniq -c | sort -n > $OB.out.l
grep -v " *1 " < $OB.out.l | grep -v " _fini$" | grep -v " _init$" > $OB.nonuniq
wc -l < $OB.nonuniq

echo "Duplicated symbols:"
for i in $(sed -e "s|.* ||g" < $OB.nonuniq) ; do
	grep -- "^$i " $OB.out.libs
done

