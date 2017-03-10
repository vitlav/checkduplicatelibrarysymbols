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

filter_libs()
{
    grep -E -v "(not found|undefined symbol|statically linked)" | sed -e "s|.*=> ||g" | sed -e "s| .*||g"
}

# libpulsecommon: https://github.com/otcshare/pulseaudio/blob/master/src/Makefile.am https://lists.freedesktop.org/archives/pulseaudio-discuss/2012-March/012961.html
# libtheora: by some reason includes libtheoraenc, libtheoradec
# TODO: some libs excludes
exclude_known()
{
    grep -E -v "(/ld-linux-.*|linux-gate.so.1|/libc-.*.so|/libc.so.*|/libz.so.*|/libm.so.*|/libpthread.so.*|/libdl.so.*|linux-vdso.so|/libselinux.so.*|libwayland|libpulsecommon|libtheora)"
}

echo "Checking $PRG ..."

echo -n "Read all libs... "
LANG=C ldd -r $PRG | grep "not found" > $OB.libs.notfound
LANG=C ldd -r $PRG | grep "undefined symbol" > $OB.libs.undefined
LANG=C ldd -r $PRG | grep "statically linked" > $OB.libs.statically
LANG=C ldd -r $PRG | filter_libs > $OB.libs
cat $OB.libs | xargs --no-run-if-empty readlink -f > $OB.libs.u
wc -l < $OB.libs.u

# path $name
req_libs()
{
    local i
    echo "$1"
    echo "$libslist" | grep -q "$2" && return
    libslist="$libslist $2"
    for i in $(LANG=C ldd $2 | filter_libs | exclude_known | xargs --no-run-if-empty readlink -f) ; do
        #echo "NN = $i"
        # stop recursion
        echo "$1" | grep -q "$i" || req_libs "$1 - $i" "$i"
    done
}

echo -n "Fill all recursion to $OB.libs.req ..."
libslist=
req_libs $PRG $PRG > $OB.libs.req
echo "DONE"

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

for i in $(cat $OB.libs.u | exclude_known ) ; do
	#$OBjdump -p $PRG | grep NEEDED
	LANG=C nm -D $i | grep " T " | sed -e "s|.* T ||g" | uniq | tee -a $OB.out | sed -e "s|$| $i|g" >> $OB.out.libs
done
wc -l < $OB.out.libs

echo -n "Get all non uniq symbols... "
sort < $OB.out | uniq -c | sort -n > $OB.out.l
# TODO: some excludes functions
grep -v " *1 " < $OB.out.l | grep -E -v " (_fini|_init|libVersionPoint)$" > $OB.nonuniq
wc -l < $OB.nonuniq

echo
echo "Duplicated symbols:"
rm -f $OB.out.dups
touch $OB.out.dups
for i in $(sed -e "s|.* ||g" < $OB.nonuniq) ; do
	grep -- "^$i " $OB.out.libs | tee -a $OB.out.dups
done | head -n20
echo "... (see $OB.out.dups file for full list)"

echo
echo "Duplicated libs:"
for i in $(cat $OB.out.dups | sed -e "s|.* ||g" | sort -u) ; do
	grep --color -- "$i" $OB.libs.req
done

[ -s $OB.nonuniq ] && [ -x /usr/bin/eepm ] && echo "$PRG $(eepm --quiet qf $PRG) with $(wc -l < $OB.nonuniq) duplicated symbols" >> $OB.found.dup
[ -s $OB.libs.undefined ] && [ -x /usr/bin/eepm ] && echo "$PRG $(eepm --quiet qf $PRG) with $(wc -l < $OB.libs.undefined) undefined symbols" >> $OB.found.undef

# error status if there are duplicated symbols
test ! -s $OB.nonuniq
