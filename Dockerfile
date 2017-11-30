FROM centos:6.7

RUN mkdir -p $HOME/local
ENV CMAKE_PREFIX_PATH=$HOME/local
ENV USE_HPHPC=1 HPHP_HOME=/build/hiphop-php HPHP_LIB=/build/hiphop-php/bin

RUN yum -y update && yum -y install wget
RUN wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm && rpm -ivh epel-release-6-8.noarch.rpm
RUN wget http://repo.enetres.net/enetres.repo -O /etc/yum.repos.d/enetres.repo

RUN yum -y update && yum -y install libc-client2007* elfutils-devel libc-client-devel \
    inotify-tools-devel kernel-devel make git cmake pcre-devel libmcrypt-devel gd-devel libxml2-devel \
    autoconf* automake* libunwind* mysql-devel \
    libcap-devel binutils-devel flex bison expat-devel \
    bzip2-devel memcached openldap openldap-devel readline-devel libc-client-devel \
    pam-devel wget ncurses-devel bzip2-devel zlib-devel patch \
    bzip2 libtool* tar oniguruma* python-devel libunistring-devel gcc-c++


RUN cp /usr/lib64/libc-client.so.2007f /usr/local/lib/libc-client.so


RUN mkdir -p /build
COPY ./src/ /build/

RUN cd /build && tar xvzf libevent-1.4.14-stable.tar.gz && \
    tar xvzf re2c-0.13.5.tar.gz && \
    tar xvzf libmemcached-0.48.tar.gz && \
    tar xvzf icu4c-4_6_1-src.tgz && \
    tar xvzf boost_1_50_0.tar.gz && \
    tar xvzf libcclient2007-devel.tar.gz

RUN cp -r /build/imap $HOME/local/include/
RUN git clone https://github.com/google/glog.git /build/glog && cd /build/glog && \
    git checkout 6aa35189 && \
    ./configure --prefix=$CMAKE_PREFIX_PATH && \
    make -j$(nproc) && \
    make install

RUN cd /build/re2c-0.13.5 && \
    ./configure --prefix=$CMAKE_PREFIX_PATH && \
    make install && \
    cd ..

RUN cd /build/libevent-1.4.14-stable && \
    patch < /build/hiphop-php/hphp/third_party/libevent-1.4.14.fb-changes.diff && \
    ./configure --prefix=$CMAKE_PREFIX_PATH && \
    make install && \
    cd ..

RUN cd /build && tar -jxvf curl-7.20.0.tar.bz2 && \
    cd curl-7.20.0 && \
    patch -p1 < /build/hiphop-php/hphp/third_party/libcurl.fb-changes.diff && \
    ./configure --prefix=$CMAKE_PREFIX_PATH && \
    make install && \
    cd ..

RUN cd /build/libmemcached-0.48 && \
    ./configure --prefix=$CMAKE_PREFIX_PATH && \
    make install && \
    cd ..

RUN cd /build/icu/source && \
    ./configure --prefix=$CMAKE_PREFIX_PATH && \
    make install && \
    cd ../..

RUN cd /build && git clone https://github.com/01org/tbb.git tbb && \
    cd tbb && git checkout tags/4.4 && \ 
    /usr/bin/gmake && \
    cp -Rp include/tbb/ /usr/include/ && \
    cp `pwd`/build/*_release/*.so /usr/lib/ && \
    cp `pwd`/build/*_release/*.so.2 /usr/lib/ && \
    ldconfig

RUN cd /build && git config --global http.sslverify false && \
    git clone https://git.code.sf.net/p/libdwarf/code libdwarf-code && \
    cd libdwarf-code && git checkout tags/20110612 && \
    cd libdwarf && \
    ./configure && make && \
    cp libdwarf.a /usr/lib64/ && \
    cp libdwarf.h /usr/include/ && cp dwarf.h /usr/include/


RUN export PATH=$PATH:/usr/lib64/mpich/bin/ && cd /build/boost_1_50_0 && \
    ./bootstrap.sh --prefix=$HOME/local --libdir=$HOME/local/lib && \
    ./bjam --layout=system install && \
    cd ..



RUN cd /build && tar jxf gmp-4.3.2.tar.bz2 && cd gmp-4.3.2/ && \
    ./configure --prefix=$HOME/local/gmp && \
    make &&make install

RUN cd /build && tar jxf mpfr-2.4.2.tar.bz2 && cd mpfr-2.4.2/ && \
    ./configure --prefix=$HOME/local/mpfr -with-gmp=$HOME/local/gmp && \
    make && make install 

RUN cd /build && tar xzf mpc-0.8.1.tar.gz && cd mpc-0.8.1 && \
    ./configure --prefix=$HOME/local/mpc -with-mpfr=$HOME/local/mpfr -with-gmp=$HOME/local/gmp && \
    make && make install


RUN cd /build && tar jxf gcc-4.6.3.tar.bz2 && cd gcc-4.6.3 && \
    ./configure --prefix=$HOME/local/gcc -enable-threads=posix -disable-checking -disable-multilib -enable-languages=c,c++ -with-gmp=$HOME/local/gmp -with-mpfr=$HOME/local/mpfr/ -with-mpc=$HOME/local/mpc/ && \
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HOME/local/mpc/lib:$HOME/local/gmp/lib:$HOME/local/mpfr/lib/ && \
    make && make install

ADD gcc.4.6.3.conf /etc/ld.so.conf.d/gcc.4.6.3.conf
RUN ldconfig && \
    #mv /usr/bin/gcc  /usr/bin/gcc_old && \
    #mv /usr/bin/g++  /usr/bin/g++_old && \
    ln -s -f $HOME/local/gcc/bin/gcc  /usr/bin/gcc && \
    ln -s -f $HOME/local/gcc/bin/g++  /usr/bin/g++ && \
    cp $HOME/local/gcc/lib64/libstdc++.so.6.0.16 /usr/lib64/. && \
    #mv /usr/lib64/libstdc++.so.6 /usr/lib64/libstdc++.so.6.bak && \
    ln -s -f /usr/lib64/libstdc++.so.6.0.16 /usr/lib64/libstdc++.so.6

ENV CC=gcc CXX=g++

RUN cd /build/hiphop-php && \
    export CMAKE_INCLUDE_PATH=$HOME/local/include && \
    export CMAKE_LIBRARY_PATH=$HOME/local/lib && \
    cmake . && \
    /build/hiphop-php/hphp/tools/generate_compiler_id.sh && \
    /build/hiphop-php/hphp/tools/generate_repo_schema.sh && \
    make -j$(nproc)

CMD /build/hiphop-php/hphp/hphp/hphp
