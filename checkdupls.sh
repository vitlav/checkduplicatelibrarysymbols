#!/bin/sh
PRG=$(which $1)
[ -x "$PRG" ] || { echo "Run with prog as arg" ; exit 1; }

echo "Checking $PRG ..."
ldd -r $PRG | sed -e "s|.*=> ||g" | sed -e "s| .*||g" > $0.libs
cat $0.libs | xargs readlink -f > $0.libs.u

rm -f $0.out $0.out.libs
for i in $(cat $0.libs.u | grep -v "linux-gate.so.1" | grep -v "/libc-.*.so" | grep -v "linux-vdso.so") ; do
	#objdump -p $PRG | grep NEEDED
	nm -D $i | grep " T " | sed -e "s|.* T ||g" | uniq | tee -a $0.out | sed -e "s|$| $i|g" >> $0.out.libs
done

sort < $0.out | uniq -c | sort -n > $0.out.l
grep -v " *1 " < $0.out.l | grep -v " _fini$" | grep -v " _init$" > $0.nonuniq

echo "Repeated:"
for i in $(sed -e "s|.* ||g" < $0.nonuniq) ; do
	grep -- "^$i " $0.out.libs
done

