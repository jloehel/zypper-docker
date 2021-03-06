// Copyright (c) 2015 SUSE LLC. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"fmt"
	"log"

	"github.com/SUSE/dockerclient"
	"github.com/codegangsta/cli"
)

// zypper-docker ps
func psCmd(ctx *cli.Context) {
	client := getDockerClient()
	containers, err := client.ListContainers(false, false, "")
	if err != nil {
		log.Println("Cannot list running containers", err)
		exitWithCode(1)
		return
	}

	cache := getCacheFile()

	matches := []dockerclient.Container{}
	notSuse := []dockerclient.Container{}
	unknown := []dockerclient.Container{}

	if len(containers) == 0 {
		log.Println("There are no running containers to analyze")
		return
	}

	for _, container := range containers {
		imageId, err := getImageId(container.Image)
		if err != nil {
			log.Printf("Cannot analyze container %s [%s]: %s", container.Id, container.Image, err)
			unknown = append(unknown, container)
			continue
		}

		if exists, suse := cache.idExists(imageId); exists && !suse {
			notSuse = append(notSuse, container)
		} else if cache.isImageOutdated(imageId) {
			matches = append(matches, container)
		} else {
			unknown = append(unknown, container)
		}
	}

	if len(matches) > 0 {
		fmt.Println("Running containers whose images have been updated:")
		for _, container := range matches {
			fmt.Printf("  - %s [%s]\n", container.Id, container.Image)
		}
		fmt.Println("It is recommended to stop the container and start a new instance based on the new image created with zypper-docker")
	}

	if len(notSuse) > 0 {
		if len(matches) > 0 {
			fmt.Printf("\n")
		}
		fmt.Println("The following containers have been ignored because are known to be based on non-SUSE systems:")

		for _, container := range notSuse {
			fmt.Printf("  - %s [%s]\n", container.Id, container.Image)
		}
	}

	if len(unknown) > 0 {
		if len(matches) > 0 || len(notSuse) > 0 {
			fmt.Printf("\n")
		}
		fmt.Println("The following containers have an unknown state:")

		for _, container := range unknown {
			fmt.Printf("  - %s [%s]\n", container.Id, container.Image)
		}

		fmt.Println("Use either the \"list-patches-container\" or the \"list-updates-container\" commands to inspect them.")
	}
}
