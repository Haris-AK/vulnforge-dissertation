# Makefile for qdissertation template (uses latexmk)
# Main dissertation file: main.tex. Example initial plan: plan.tex.
# Run: make help for targets.
#
# LaTeX engine: set ENGINE to lua (default), pdf, or xe.
#   make              # lualatex
#   make ENGINE=pdf
#   make ENGINE=xe
#
# SPDX-FileCopyrightText: 2026 Frank Langbein <frank@langbein.org>
# SPDX-License-Identifier: LPPL-1.3c

MAIN = main
PLAN = plan
ENGINE ?= lua
# Seed used for obfuscated fonts. Override with `make hacker-font SEED=...`.
# If not provided, we pick a timestamp seed so all generated fonts share one permutation.
SEED ?= $(shell date +%s)

# ------------------------------------------------------------------------------
# Default: build dissertation and example plan (first target).
# Run "make help" for all targets.
# ------------------------------------------------------------------------------
.PHONY: all
all: $(MAIN).pdf $(PLAN).pdf

# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------
help:
	@echo "qdissertation template Makefile targets:"
	@echo "  make [all]     Build $(MAIN).pdf and $(PLAN).pdf (default)."
	@echo "  make main      Build $(MAIN).pdf only."
	@echo "  make plan      Build $(PLAN).pdf only (initial plan example)."
	@echo "  make help      Show this help."
	@echo "  make clean    Remove build artifacts (keep PDF)."
	@echo "  make distclean  clean + remove $(MAIN).pdf"
	@echo "  make hacker-font  Generate obfuscated font and permutation (default: hacker; optional SEED=n). See README for sans/serif."
	@echo "  make wordcount  Per-file and total word count (captions shown separately)."
	@echo "  make check    Run quality checks (REUSE lint, optional dissertation-specific)."
	@echo ""
	@echo "Engine: make ENGINE=lua (default) | ENGINE=pdf | ENGINE=xe"

# latexmk engine flag and compiler command for nonstopmode + file-line-error
ifeq ($(ENGINE),xe)
  LATEXMK_ENGINE = -xelatex
  LATEXMK_CMD = -xelatex="xelatex -interaction=nonstopmode -file-line-error %O %S"
else
  ifeq ($(ENGINE),lua)
    LATEXMK_ENGINE = -lualatex
    LATEXMK_CMD = -lualatex="lualatex -interaction=nonstopmode -file-line-error %O %S"
  else
    LATEXMK_ENGINE = -pdf
    LATEXMK_CMD = -pdflatex="pdflatex -interaction=nonstopmode -file-line-error %O %S"
  endif
endif

LATEXMK = latexmk
LATEXMK_OPTS ?= -f

.PHONY: clean distclean wordcount check help hacker-font main plan

# ------------------------------------------------------------------------------
# Obfuscation: generate permuted fonts + permutation table
#
# This builds the obfuscated fonts used by the `obfuscate` class option:
# - fonts/sans-obfuscated*.otf
# - fonts/serif-obfuscated*.otf
# - fonts/hacker-obfuscated*.otf
#
# All files MUST share the same SEED so they all match the same obfuscation
# permutation table (fonts/obfuscate-perm.lua).
# ------------------------------------------------------------------------------
OBF_OUT_DIR := fonts

SANS_SRC_REG := $(shell kpsewhich SourceSansPro-Regular.otf)
SANS_SRC_BOLD := $(shell kpsewhich SourceSansPro-Bold.otf)
SANS_SRC_ITALIC := $(shell kpsewhich SourceSansPro-RegularIt.otf)
SANS_SRC_BOLDITALIC := $(shell kpsewhich SourceSansPro-BoldIt.otf)
ifeq ($(SANS_SRC_REG),)
  SANS_SRC_REG := $(shell kpsewhich texgyreheros-regular.otf)
  SANS_SRC_BOLD := $(shell kpsewhich texgyreheros-bold.otf)
  SANS_SRC_ITALIC := $(shell kpsewhich texgyreheros-italic.otf)
  SANS_SRC_BOLDITALIC := $(shell kpsewhich texgyreheros-bolditalic.otf)
endif

SERIF_SRC_REG := $(shell kpsewhich SourceSerifPro-Regular.otf)
SERIF_SRC_BOLD := $(shell kpsewhich SourceSerifPro-Bold.otf)
SERIF_SRC_ITALIC := $(shell kpsewhich SourceSerifPro-RegularIt.otf)
SERIF_SRC_BOLDITALIC := $(shell kpsewhich SourceSerifPro-BoldIt.otf)
ifeq ($(SERIF_SRC_REG),)
  SERIF_SRC_REG := $(shell kpsewhich texgyretermes-regular.otf)
  SERIF_SRC_BOLD := $(shell kpsewhich texgyretermes-bold.otf)
  SERIF_SRC_ITALIC := $(shell kpsewhich texgyretermes-italic.otf)
  SERIF_SRC_BOLDITALIC := $(shell kpsewhich texgyretermes-bolditalic.otf)
endif

# Prefer Inconsolata if available, else Fira Mono (both are commonly present in TeX Live)
HACKER_SRC_REG := $(firstword $(shell kpsewhich Inconsolata-Regular.otf Inconsolata-Regular.ttf inconsolata-regular.otf inconsolata-regular.ttf FiraMono-Regular.otf FiraMono-Regular.ttf))
HACKER_SRC_BOLD := $(firstword $(shell kpsewhich Inconsolata-Bold.otf Inconsolata-Bold.ttf inconsolata-bold.otf inconsolata-bold.ttf FiraMono-Bold.otf FiraMono-Bold.ttf))

define obfuscate_font
	@if [ -n "$(1)" ]; then \
	  python3 scripts/build-hacker-font.py --output-dir "$(OBF_OUT_DIR)" --seed "$(SEED)" --font "$(1)" --output-font "$(2)"; \
	else \
	  echo "Skipping $(2) (missing source font)"; \
	fi
endef

hacker-font:
	@mkdir -p "$(OBF_OUT_DIR)"
	@echo "Generating obfuscated fonts into $(OBF_OUT_DIR) (SEED=$(SEED))"
	$(call obfuscate_font,$(SANS_SRC_REG),sans-obfuscated.otf)
	$(call obfuscate_font,$(SANS_SRC_BOLD),sans-obfuscated-Bold.otf)
	$(call obfuscate_font,$(SANS_SRC_ITALIC),sans-obfuscated-Italic.otf)
	$(call obfuscate_font,$(SANS_SRC_BOLDITALIC),sans-obfuscated-BoldItalic.otf)
	$(call obfuscate_font,$(SERIF_SRC_REG),serif-obfuscated.otf)
	$(call obfuscate_font,$(SERIF_SRC_BOLD),serif-obfuscated-Bold.otf)
	$(call obfuscate_font,$(SERIF_SRC_ITALIC),serif-obfuscated-Italic.otf)
	$(call obfuscate_font,$(SERIF_SRC_BOLDITALIC),serif-obfuscated-BoldItalic.otf)
	$(call obfuscate_font,$(HACKER_SRC_REG),hacker-obfuscated.otf)
	$(call obfuscate_font,$(HACKER_SRC_BOLD),hacker-obfuscated-Bold.otf)
	@echo "Done. Use class option 'obfuscate' with font=sans, serif, or hacker (ENGINE=lua). See README."

$(MAIN).pdf: $(MAIN).tex qdissertation.cls bibliography.bib acronyms.tex \
	C*/chapter*.tex A*/appendix*.tex
	$(LATEXMK) $(LATEXMK_OPTS) $(LATEXMK_ENGINE) $(LATEXMK_CMD) $(MAIN)
	-makeglossaries $(MAIN)
	$(LATEXMK) $(LATEXMK_OPTS) -g $(LATEXMK_ENGINE) $(LATEXMK_CMD) $(MAIN)

$(PLAN).pdf: $(PLAN).tex qproposal.cls bibliography.bib acronyms.tex
	$(LATEXMK) $(LATEXMK_OPTS) $(LATEXMK_ENGINE) $(LATEXMK_CMD) $(PLAN)
	-makeglossaries $(PLAN)
	$(LATEXMK) $(LATEXMK_OPTS) -g $(LATEXMK_ENGINE) $(LATEXMK_CMD) $(PLAN)

main: $(MAIN).pdf

plan: $(PLAN).pdf

clean:
	$(LATEXMK) -c $(MAIN)
	rm -f *.aux *.log *.out *.toc *.lof *.lot *.loa
	rm -f *.bbl *.blg *.run.xml *.bcf
	rm -f *.acn *.acr *.alg *.glg *.glo *.gls *.ist
	rm -f *.fls *.fdb_latexmk *.synctex.gz

distclean: clean
	rm -f $(MAIN).pdf $(PLAN).pdf
	rm -rf fonts

# Word count: includes \input files (-inc). Full count = text + headers + captions.
# Caption words are shown separately per file and in total.
wordcount:
	@echo "Word count per file (total = text + headers + captions):"; \
	texcount -quiet -inc -sum=1,1,1,0,0,0,0 $(MAIN).tex 2>/dev/null | awk '\
	  /^File: / { f=$$2 } \
	  /^Included file: \.\// { sub(/^Included file: \.\//,""); f=$$0 } \
	  /^Sum count: / { if (f != "") { s=$$3 } else if (tot) { total_sum=$$3 } } \
	  /^Words outside text \(captions/ { c=$$NF; if (f != "" && s != "") { print "  " f ": " s " words (" c " in captions)"; tw+=s; tc+=c; f=""; s="" } else if (total_sum != "") { print ""; print "  Total: " total_sum " words (" c " in captions)"; exit } } \
	  /^File\(s\) total:/ { tot=1 } \
	  END { if (total_sum == "" && tw != "") print "\n  Total: " tw " words (" tc " in captions)" }' \
	  || (echo "  (texcount failed; fallback: detex+wc)"; detex $(MAIN).tex 2>/dev/null | wc -w)

# ------------------------------------------------------------------------------
# Check: REUSE lint (license/copyright) and optional dissertation-specific checks
# ------------------------------------------------------------------------------
check:
	@echo "Running REUSE lint (license/copyright compliance)..."; \
	if command -v reuse >/dev/null 2>&1; then reuse lint; else echo "  (reuse not installed; install from https://reuse.software to enable)"; fi
	@echo "Check done. Add custom checks above (data validation, etc.)."
