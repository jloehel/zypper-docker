VERSIONS = 1.0.1 1.0.2 1.0.3 1.0.3 1.1.1 1.1.2 1.1 1.2.2 1.3 1.3.1 1.3.2 1.3.3 1.4 1.4.1 1.4.2 1.5

test ::
		@echo Start testing ...
		for version in $(VERSIONS);do \
			docker run --name zypper-docker-testing zypper-docker
			echo Switch to Go $$version; \
			docker run --volumes-from zypper-docker-testing -v `pwd`:/go/src/github.com/SUSE/zypper-docker zypper-docker gimme $$version; \
			docker run --volumes-from zypper-docker-testing -v `pwd`:/go/src/github.com/SUSE/zypper-docker zypper-docker /bin/bash/ -c "source ~/.gimme/envs/go$${version}.env"; \
			@echo Running unit test inside of Go $$version; \
			docker run --volumes-from zypper-docker-testing -v `pwd`:/go/src/github.com/SUSE/zypper-docker zypper-docker godep go test -race -v ./...; \
			@echo Running climate inside of Go $$version; \
			docker run --volumes-from zypper-docker-testing -v `pwd`:/go/src/github.com/SUSE/zypper-docker zypper-docker climate -open=false -threshold=80.0 -errcheck -vet -fmt .; \
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
