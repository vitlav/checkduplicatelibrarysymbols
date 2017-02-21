#!/bin/sh
PRG=$(which $1)
[ -x "$PRG" ] || { echo "Run with prog as arg" ; exit 1; }

OB=checkdupls

echo "Checking $PRG ..."

echo -n "Read all libs... "
ldd -r $PRG | sed -e "s|.*=> ||g" | sed -e "s| .*||g" > $OB.libs
cat $OB.libs | xargs readlink -f > $OB.libs.u
wc -l < $OB.libs.u

echo -n "Get all symbols... "
rm -f $OB.out $OB.out.libs
for i in $(cat $OB.libs.u | grep -v "linux-gate.so.1" | grep -v "/libc-.*.so" | grep -v "linux-vdso.so") ; do
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

