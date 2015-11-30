#
# Edit the REGISTRY_HOST, USERNAME and NAME as required
#
REGISTRY_HOST=docker.io
USERNAME=cargonauts
NAME=$(shell basename $(PWD))

IMAGE=$(REGISTRY_HOST)/$(USERNAME)/$(NAME)

VERSION=$(shell . .make-release-support ; getVersion)
TAG=$(shell . .make-release-support; getTag)

build: .release
	docker build -t $(IMAGE):$(VERSION) .
	docker tag  -f $(IMAGE):$(VERSION) $(IMAGE):latest

.release:
	@echo "release=0.0.0" > .release
	@echo "tag=$(NAME)-0.0.0" >> .release
	@echo INFO: .release created

release: check-status check-release build
	docker build --no-cache --force-rm -t $(IMAGE):$(VERSION) .
	docker tag  -f $(IMAGE):$(VERSION) $(IMAGE):latest
	docker push $(IMAGE):$(VERSION)
	docker push $(IMAGE):latest

patch-release: VERSION = $(shell . .make-release-support; nextPatchLevel)
patch-release: tag 

minor-release: VERSION = $(shell . .make-release-support; nextMinorLevel)
minor-release: tag 

major-release: VERSION = $(shell . .make-release-support; nextMajorLevel)
major-release: tag 

tag: TAG=$(shell . .make-release-support; getTag $(VERSION))
tag: check-status
	@. .make-release-support ; ! tagExists $(TAG) || (echo "ERROR: tag $(TAG) for version $(VERSION) already tagged in git" >&2 && exit 1) ; 
	@. .make-release-support ; setRelease $(VERSION)
	git add .release 
	git commit -m "bumped to version $(VERSION)" ; 
	git tag $(TAG) ;
	@test -z "$(shell git remote -v)" || git push --tags

check-status:
	@. .make-release-support ; ! hasChanges || (echo "ERROR: there are still outstanding changes" >&2 && exit 1) ; 

check-release: 
	@. .make-release-support ; tagExists $(TAG) || (echo "ERROR: version not yet tagged in git. make [minor,major,patch]-release." >&2 && exit 1) ; 
	@. .make-release-support ; ! differsFromRelease $(TAG) || (echo "ERROR: current directory differs from tagged $(TAG). make [minor,major,patch]-release." ; exit 1) 

