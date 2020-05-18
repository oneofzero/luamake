cd Src
chmod 777 build.sh
./build.sh
cp -f luamake ../Bin/luamake/luamake
chmod 777 ../Bin/luamake/luamake
cd ..
ln -s $(pwd)/Bin/luamake/luamake /usr/bin/luamake