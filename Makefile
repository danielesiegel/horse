.PHONY: build deploy clean

build:
	chmod +x ./forester
	./forester build forest.toml

deploy: build
	npx wrangler pages deploy output --project-name bci-horse --commit-dirty=true

clean:
	rm -rf output build
