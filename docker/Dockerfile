FROM golang

RUN go get github.com/mssola/climate
RUN go get golang.org/x/tools/cmd/cover
RUN go get golang.org/x/tools/cmd/vet
RUN go get github.com/golang/lint/golint
RUN go get github.com/kisielk/errcheck
RUN go get github.com/tools/godep
RUN curl -sL -o /usr/bin/gimme https://raw.githubusercontent.com/travis-ci/gimme/master/gimme
RUN chmod +x /usr/bin/gimme

WORKDIR /go/src/github.com/SUSE/zypper-docker
ENV GOPATH=/go:/go/src/github.com/SUSE/zypper-docker/Godeps/_workspace/
ENV GIMME_OS=linux
ENV GIMME_ARCH=amd64


RUN useradd -m travis
USER travis
RUN mkdir /home/travis/.testing/
ADD ./test.sh /home/travis/.testing/test.sh
