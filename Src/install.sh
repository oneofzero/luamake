#!/bin/bash
cp -f luamake ../Bin/luamake/luamake
chmod 777 ../Bin/luamake/luamake
echo $(pwd)
cd ..
ln -s $(pwd)/Bin/luamake/luamake /usr/bin/luamake