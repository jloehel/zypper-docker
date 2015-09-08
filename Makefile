test ::
		@echo Start testing ...
		VERSIONS = 1.0.1 1.0.2 1.0.3 1.0.3 1.1.1 1.1.2 1.1 1.2.2 1.3 1.3.1 1.3.2 1.3.3 1.4 1.4.1 1.4.2 1.5
		for version in $(VERSIONS);do \
			echo Switch to Go $$version; \
			docker run --rm -v zypper-docker-testing gimme $$version; \
			docker run --rm -v zypper-docker-testing source ~/.gimme/envs/go$${version}.env; \
			@echo Running unit test inside of Go $$version; \
			docker run --rm -v `pwd`:/go/src/github.com/SUSE/zypper-docker zypper-docker-testing godep go test -race -v ./...; \
			@echo Running climate inside of Go $$version; \
			docker run --rm -v `pwd`:/go/src/github.com/SUSE/zypper-docker zypper-docker-testing climate -open=false -threshold=80.0 -errcheck -vet -fmt .; \
		done


clean ::
		docker images | grep -q zypper-docker-testing && docker rmi zypper-docker-testing || echo "No testing image found"

build ::
		@echo Building zypper-docker-testing
		docker build -f docker/Dockerfile -t zypper-docker-testing docker
help ::
		@echo usage: make [target]
		@echo
		@echo build: Creates the dockerimage.
		@echo clean: Remove the dockerimage.
		@echo test: Testing zypper-docker.
