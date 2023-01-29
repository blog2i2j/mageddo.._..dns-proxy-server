#!/bin/sh

set -e

CUR_DIR=`pwd`
APP_VERSION=$(cat VERSION)
REPO_URL=mageddo/dns-proxy-server


assemble(){
	echo "> Testing ..."
	go test -p 1 -cover -ldflags "-X github.com/mageddo/dns-proxy-server/flags.version=test" ./.../
	echo "> Tests completed"

	echo "> Building..."

	rm -rf build/
	mkdir -p build/

	cp -r /static build/
}

generateDocs(){
	echo "> Generating docs version=${1}, target=${2}"
	mkdir -p "${2}"
	hugo --baseURL=http://mageddo.github.io/dns-proxy-server/$1 \
	--destination $2 \
	--ignoreCache --source docs/

	echo "> Generated docs version=$1, out files:"
	ls -lha $2
}

case $1 in

	setup-repository )
		git remote remove origin  && git remote add origin https://${REPO_TOKEN}@github.com/$REPO_URL.git
		git checkout -b build_branch ${CURRENT_BRANCH}
		echo "> Repository added, previousBranch=${CURRENT_BRANCH}"

	;;

	upload-release )

		DESC=$(cat RELEASE-NOTES.md | awk 'BEGIN {RS="|"} {print substr($0, 0, index(substr($0, 3), "###"))}' | sed ':a;N;$!ba;s/\n/\\r\\n/g')
		github-cli release mageddo dns-proxy-server $APP_VERSION $CURRENT_BRANCH "${DESC}" $PWD/build/*.tgz

	;;

	docs )

	VERSION=$(cat VERSION | awk -F '.' '{ print $1"."$2}');
	rm -r ${PWD}/build/docs || echo "> build dir already clear"

	TARGET=${PWD}/build/docs/${VERSION}
	generateDocs ${VERSION} ${TARGET}

	VERSION=latest
	TARGET=${PWD}/build/docs/${VERSION}
	generateDocs ${VERSION} ${TARGET}

	;;

	apply-version )

		# updating files version
		sed -i -E "s/(dns-proxy-server.*)[0-9]+\.[0-9]+\.[0-9]+/\1$APP_VERSION/" docker-compose.yml
		sed -i -E "s/[0-9]+\.[0-9]+\.[0-9]+/$APP_VERSION/g" Dockerfile*.hub

	;;

	assemble )
		assemble
	;;

	build )

		assemble

		if [ ! -z "$2" ]
		then
			builder.bash compile $2 $3
			exit 0
		fi

		# ARM
		builder.bash compile linux arm
		builder.bash compile linux arm64

		# LINUX
		# INTEL / AMD
		builder.bash compile linux 386
		builder.bash compile linux amd64

		echo "> Build success"

	;;

	compile )
		export GOOS=$2
		export GOARCH=$3
		echo "> Compiling os=${GOOS}, arch=${GOARCH}"
		go build -o $PWD/build/dns-proxy-server -ldflags "-X github.com/mageddo/dns-proxy-server/flags.version=$APP_VERSION"
		TAR_FILE=dns-proxy-server-${GOOS}-${GOARCH}-${APP_VERSION}.tgz
		cd $PWD/build/
		tar --exclude=*.tgz -czf $TAR_FILE *
	;;

	validate-release )

		if git rev-parse "$APP_VERSION^{}" >/dev/null 2>&1; then
			echo "> Version already exists $APP_VERSION"
			exit 3
		fi

	;;

	deploy-ci )

	./builder.bash validate-release || echo ": $?"

	echo "> Build test and generate the binaries to the output dir"
	EC=0
	docker-compose up --force-recreate --abort-on-container-exit prod-ci-deploy || EC=$?
	if [ "$EC" = "3" ]; then
		exit 0
	elif [ "$EC" -ne "0" ]; then
		exit $EC
	fi

	echo "> From the binaries, build the docker images then push them to docker hub"
	docker-compose build prod-build-image-dps prod-build-image-dps-arm7x86 prod-build-image-dps-arm8x64 &&\
	docker tag defreitas/dns-proxy-server:${APP_VERSION} defreitas/dns-proxy-server:latest &&\
	echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin &&\
	docker-compose push prod-build-image-dps prod-build-image-dps-arm7x86 prod-build-image-dps-arm8x64 &&
	docker push defreitas/dns-proxy-server:latest

	;;

	release )

		echo "> build started, current branch=$CURRENT_BRANCH"
		if [ "$CURRENT_BRANCH" = "master" ]; then
			echo "> deploying new version"
			builder.bash validate-release && builder.bash apply-version && builder.bash build && builder.bash upload-release

		else
			echo "> refusing to keep going outside the master branch"
		fi

	;;

esac
