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
LANG=C ldd -r $PRG | grep "not found" > $OB.libs.notfound
LANG=C ldd -r $PRG | grep "undefined symbol" > $OB.libs.undefined
LANG=C ldd -r $PRG | grep "statically linked" > $OB.libs.statically
LANG=C ldd -r $PRG | grep -E -v "(not found|undefined symbol|statically linked)" | sed -e "s|.*=> ||g" | sed -e "s| .*||g" > $OB.libs
cat $OB.libs | xargs --no-run-if-empty readlink -f > $OB.libs.u
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
touch $OB.out $OB.out.libs

# libpulsecommon: https://github.com/otcshare/pulseaudio/blob/master/src/Makefile.am https://lists.freedesktop.org/archives/pulseaudio-discuss/2012-March/012961.html
# libtheora: by some reason includes libtheoraenc, libtheoradec
# TODO: some libs excludes
for i in $(cat $OB.libs.u | grep -E -v "(linux-gate.so.1|/libc-.*.so|linux-vdso.so|libwayland|libpulsecommon|libtheora)") ; do
	#$OBjdump -p $PRG | grep NEEDED
	LANG=C nm -D $i | grep " T " | sed -e "s|.* T ||g" | uniq | tee -a $OB.out | sed -e "s|$| $i|g" >> $OB.out.libs
done
wc -l < $OB.out.libs

echo -n "Get all non uniq symbols... "
sort < $OB.out | uniq -c | sort -n > $OB.out.l
# TODO: some excludes functions
grep -v " *1 " < $OB.out.l | grep -E -v " (_fini|_init|libVersionPoint)$" > $OB.nonuniq
wc -l < $OB.nonuniq

echo "Duplicated symbols:"
for i in $(sed -e "s|.* ||g" < $OB.nonuniq) ; do
	grep -- "^$i " $OB.out.libs
done

[ -s $OB.nonuniq ] && [ -x /usr/bin/eepm ] && echo "$PRG $(eepm --quiet qf $PRG) with $(wc -l < $OB.nonuniq) duplicated symbols" >> $OB.found.dup
[ -s $OB.libs.undefined ] && [ -x /usr/bin/eepm ] && echo "$PRG $(eepm --quiet qf $PRG) with $(wc -l < $OB.libs.undefined) undefined symbols" >> $OB.found.undef

# error status if there are duplicated symbols
test ! -s $OB.nonuniq
