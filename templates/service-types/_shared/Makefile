# Verification loop for generated Java service repos (skills reference `make verify`).
.PHONY: build test itest lint verify smoke

build:
	./gradlew assemble

test:
	./gradlew test

itest:
	./gradlew check

lint:
	./gradlew checkstyleMain checkstyleTest

# One verification CLI reused by every agent (poteto: build the knife once).
verify:
	bash scripts/app-verify.sh all

smoke:
	bash scripts/app-verify.sh smoke
