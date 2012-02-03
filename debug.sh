# I think Ill only keep the code blocks project for debuging
g++ -g -O2 -std=c++0x src/*.cpp -o luaserver -lluajit-5.1 -lrt -lmicrohttpd
gdb ./luaserver
