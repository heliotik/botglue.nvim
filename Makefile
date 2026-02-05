.PHONY: fmt fmt-check lint test pr-ready

fmt:
	@echo "===> Formatting"
	stylua lua/ plugin/ --config-path=.stylua.toml

fmt-check:
	@echo "===> Checking format"
	stylua lua/ plugin/ --config-path=.stylua.toml --check

lint:
	@echo "===> Linting"
	luacheck lua/ plugin/ --globals vim

test:
	@echo "===> Testing"
	nvim --headless --noplugin -u test/minimal_init.lua \
		-c "PlenaryBustedDirectory test/botglue {minimal_init = 'test/minimal_init.lua'}"

pr-ready: lint test fmt-check
	@echo "===> All checks passed!"
