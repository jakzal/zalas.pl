HUGO_CONTAINER ?= zalas-pl
HUGO_CACHE_PATH ?= $(PWD)/.hugo_cache
HUGO_IMAGE ?= hugomods/hugo:ci-0.147.4

build: hugo-build
.PHONY: build

hugo-build: BASE_URL ?= https://zalas.pl
hugo-build:
	docker run --rm -v $(PWD):/src -e HUGO_ENVIRONMENT -v $(HUGO_CACHE_PATH):/tmp/hugo_cache $(HUGO_IMAGE) \
	  hugo --gc --minify --baseURL "$(BASE_URL)" --cacheDir "/tmp/hugo_cache"
.PHONY: hugo-build

hugo-run: HUGO_RUN_CMD ?= server -D
hugo-run: HUGO_PORT ?= 1313
hugo-run:
	docker run --name $(HUGO_CONTAINER) --rm -it -e HUGO_ENVIRONMENT -v $(PWD):/src -v $(HUGO_CACHE_PATH):/tmp/hugo_cache -p $(HUGO_PORT):1313 $(HUGO_IMAGE) $(HUGO_RUN_CMD)
.PHONY: run

hugo-exec: HUGO_EXEC_CMD ?= /bin/sh
hugo-exec:
	docker exec -it $(HUGO_CONTAINER) $(HUGO_EXEC_CMD)
.PHONY: exec

hugo-new-post: NAME ?= rename-me
hugo-new-post:
	$(MAKE) hugo-run HUGO_CONTAINER=hugo-new-post HUGO_RUN_CMD="hugo new content/posts/$(NAME)/index.md" HUGO_PORT=11313
.PHONY: hugo-new-post
