VERSIONS = 1.4 1.5 tip

test ::
		@echo Start testing ...
		for version in $(VERSIONS);do \
			docker run -rm -v `pwd`:/go/src/github.com/SUSE/zypper-docker zypper-docker /bin/bash -c "~/.testing/test.sh $${version}"; \
		done


clean ::
		docker images | grep -q zypper-docker && docker rmi zypper-docker || echo "No testing image found"

build ::
		@echo Building zypper-docker
		docker build -f docker/Dockerfile -t zypper-docker docker
help ::
		@echo usage: make [target]
		@echo
		@echo build: Creates the dockerimage.
		@echo clean: Remove the dockerimage.
		@echo test: Testing zypper-docker.
