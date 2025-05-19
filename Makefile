HUGO_CONTAINER ?= zalas-pl

hugo-run: HUGO_CACHE_PATH ?= $(PWD)/.hugo_cache
hugo-run: HUGO_RUN_CMD ?= server -D
hugo-run:
	docker run --name $(HUGO_CONTAINER) --rm -it -v $(PWD):/src -v $(HUGO_CACHE_PATH):/tmp/hugo_cache -p 1313:1313 hugomods/hugo:ci-non-root $(HUGO_RUN_CMD)
.PHONY: run

hugo-exec: HUGO_EXEC_CMD ?= /bin/sh
hugo-exec:
	docker exec -it $(HUGO_CONTAINER) $(HUGO_EXEC_CMD)
.PHONY: exec

hugo-new-post: NAME ?= rename-me.md
hugo-new-post:
	$(MAKE) hugo-exec HUGO_EXEC_CMD="hugo new content/posts/$(NAME)"
.PHONY: hugo-new-post
