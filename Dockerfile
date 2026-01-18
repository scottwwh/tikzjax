FROM ubuntu:20.04

# Updating (to match web2js) causes issues installing node-kpathsea.git
# later on, seemingly related to nodegyp ?
# FROM ubuntu:24.04

RUN apt update

RUN apt-get update && \
	apt-get install -yq tzdata && \
	ln -fs /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
	dpkg-reconfigure -f noninteractive tzdata

RUN apt install -y make build-essential curl openssh-client git
RUN apt install -y libkpathsea-dev

#### TEXLIVE ###############################################

RUN apt install -y texlive
RUN apt install -y texlive-latex-extra
# Confirm latest in upstream
# RUN apt install -y texlive-latex-recommended
# RUN apt install -y texlive-pictures
# RUN apt install -y texlive-plain-generic

#### NODEJS ################################################

# needed for installing nvm (see https://stackoverflow.com/a/57344191/1444650)
SHELL ["/bin/bash", "--login", "-c"]

WORKDIR /code

# https://stackoverflow.com/a/57546198/1444650
ENV NODE_VERSION=16.16.0
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
ENV NVM_DIR=/root/.nvm
RUN . "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm use v${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm alias default v${NODE_VERSION}
ENV PATH="/root/.nvm/versions/node/v${NODE_VERSION}/bin/:${PATH}"
RUN node --version
RUN npm --version

#### WEB2JS ################################################

# clone web2js and switch to ww-modifications branch
# RUN git clone https://github.com/drgrice1/web2js.git
# WORKDIR /code/web2js
# 
# Testing with latest since it's been a couple of years
# RUN git checkout d78ef1f3ec94520c88049b1de36ecf6be2a65c10


# Temp (personal) branch
RUN git clone -b test/old-branch https://github.com/scottwwh/web2js.git --single-branch
WORKDIR /code/web2js
# 
# Include changes to preamble (from latest)
# RUN git checkout feature/fillbetween
#
# Force specific commit with changes (lean into the cache)
RUN git pull
RUN git checkout a96f31bcb42d5554c03ddcf434afa72c74cdc2c0

# switch to https:// protocol because github deprecated git://
# https://github.com/npm/cli/issues/4896#issuecomment-1128472004
RUN npm install --save https://github.com/kisonecat/node-kpathsea.git
RUN npm install --save-dev wasm-opt

# generate tex.wasm and core.dump files
RUN npm install --loglevel verbose

# Old commit
RUN npm run build
RUN npm run generate-wasm
RUN ./node_modules/wasm-opt/bin/wasm-opt --asyncify --pass-arg=asyncify-ignore-indirect --pass-arg=asyncify-imports@library.reset -O4 out.wasm -o tex.wasm
RUN node initex.js

# Latest script now includes all subsequent steps
# RUN npm run build

# compress tex.wasm and core.dump
RUN gzip tex.wasm
RUN gzip core.dump

#### TIKZJAX ###############################################

WORKDIR /code

# install tikzjax dependencies
RUN apt install -y software-properties-common
RUN add-apt-repository universe
RUN apt update
RUN apt install -y fontforge

# copy local tikzjax source folder
COPY . ./tikzjax

# copy tex.wasm and core.dump to tikzjax folder
RUN cp /code/web2js/tex.wasm.gz /code/tikzjax
RUN cp /code/web2js/core.dump.gz /code/tikzjax

# build tikzjax
WORKDIR /code/tikzjax
RUN npm install
RUN npm run gen-tex-files
RUN npm run build