# Makefile for leanmacs.
#
#   make test      run the batch ERT suite (no Lean server needed)
#   make compile   byte-compile all sources (warnings shown)
#   make clean     remove byte-compiled files
#
# Override the Emacs binary with e.g. `make EMACS=emacs-30.1 test`.
# The end-to-end test (test/e2e.el) needs a live Lean toolchain and is not
# part of `make test'; run it manually -- see test/e2e.el.

EMACS ?= emacs

SRC   := $(wildcard leanmacs*.el)
TESTS := test/leanmacs-render-test.el test/leanmacs-input-test.el

.PHONY: test compile clean

test:
	$(EMACS) -Q --batch -L . \
	  $(addprefix -l ,$(TESTS)) \
	  -f ert-run-tests-batch-and-exit

compile:
	$(EMACS) -Q --batch -L . -f batch-byte-compile $(SRC)
	@$(RM) *.elc

clean:
	$(RM) *.elc test/*.elc
