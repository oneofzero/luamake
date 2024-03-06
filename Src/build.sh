#! /bin/bash
osname=`uname  -a`
macos="Darwin"
if [[ $osname =~ $macos ]];then
echo "mac os"
    osdefine="-DMAC"
    gcc macpopen.mm -g -c -o macpopen.mm.o
    linkflag="macpopen.mm.o -framework Foundation"
else
    osdefine="-DLINUX"
    linkflag="-lgcc -static-libgcc -static-libstdc++ -static"
fi
g++ luamake.cpp $osdefine -g -c -o luamake.o
g++ threadmsg.cpp -std=gnu++11 $osdefine -g -c -o threadmsg.o

luafiles=('lapi' 'lauxlib' 'lbaselib' 'lbitlib' 'lcode' 'lcorolib' 'lctype' 'ldblib' 'ldebug' 'ldo' 'ldump' 'lfunc' 'lgc' 'linit' 'liolib' 'llex' 'lmathlib' 'lmem' 'loadlib' 'lobject' 'lopcodes' 'loslib' 'lparser' 'lstate' 'lstring' 'lstrlib' 'ltable' 'ltablib' 'ltm' 'lundump' 'lutf8lib' 'lvm' 'lzio')

alllua=''

for item in ${luafiles[@]};do
 echo $item
 gcc $item.c $osdefine -DLUA_USE_POSIX -DLUA_USE_DLOPEN -g -c -o $item.o
 alllua=$alllua' '$item.o
done

echo $alllua

g++ threadmsg.o luamake.o $alllua -o luamake -ldl -lc -lpthread $linkflag
