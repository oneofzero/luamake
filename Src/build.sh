#! /bin/bash
g++ luamake.cpp -DLINUX -c -o luamake.o
g++ threadmsg.cpp -std=gnu++11 -DLINUX -c -o threadmsg.o
luafiles=('lapi' 'lauxlib' 'lbaselib' 'lbitlib' 'lcode' 'lcorolib' 'lctype' 'ldblib' 'ldebug' 'ldo' 'ldump' 'lfunc' 'lgc' 'linit' 'liolib' 'llex' 'lmathlib' 'lmem' 'loadlib' 'lobject' 'lopcodes' 'loslib' 'lparser' 'lstate' 'lstring' 'lstrlib' 'ltable' 'ltablib' 'ltm' 'lundump' 'lutf8lib' 'lvm' 'lzio')

alllua=''

for item in ${luafiles[@]};do
 echo $item
 gcc $item.c -DLUA_USE_POSIX -DLUA_USE_DLOPEN -c -o $item.o
 alllua=$alllua' '$item.o
done

echo $alllua

g++ threadmsg.o luamake.o $alllua -o luamake -ldl -lgcc -lc -lpthread -static-libgcc -static-libstdc++ -static