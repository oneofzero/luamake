cd Src
chmod 777 build.sh
./build.sh
cp -f luamake ../Bin/luamake/luamake
chmod 777 ../Bin/luamake/luamake
cd ..
rm -f /usr/bin/luamake
ln -s $(pwd)/Bin/luamake/luamake /usr/bin/luamake