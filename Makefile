DEB_HOST_MULTIARCH ?= $(shell dpkg-architecture -qDEB_HOST_MULTIARCH)
DEB_HOST_ARCH ?= $(shell dpkg-architecture -qDEB_HOST_ARCH)
prefix?=/usr
exec_prefix?=$(prefix)
DESTDIR?=
libexecdir?=$(exec_prefix)/libexec
archlibexecdir?=$(exec_prefix)/libexec/$(DEB_HOST_MULTIARCH)
INSTALL?=install

uniq = $(if $1,$(firstword $1) $(call uniq,$(filter-out $(firstword $1),$1)))

ISAS_ARCH_LIST:=$(shell cat isa-list | grep '^Architecture:' | cut -d ':' -f2 | sort -u)
ISAS_ARCH_FORUS:=$(call uniq, $(foreach isaarch, $(ISAS_ARCH_LIST), $(shell dpkg-architecture -a $(DEB_HOST_ARCH) -i $(isaarch) && echo $(isaarch))))
ISAS_ARCH_FORUS_GREP:=$(foreach isa, $(ISAS_ARCH_FORUS), -e '^Architecture:.*[[:space:]]$(isa)')

ISAS:= $(shell cat isa-list | grep -A1 ^Name  | grep -B1 $(ISAS_ARCH_FORUS_GREP) -e 'FakeArchIsEmptySet' | grep ^Name | cut -d ' ' -f2)



TEST_BINARIES = $(foreach isa,$(ISAS),test-$(isa))
QEMU_BINARIES = $(foreach type,good static-good bad static-bad,$(foreach isa,$(ISAS),qemu-$(type)-$(isa)))
TEST_SOURCES = $(foreach isa,$(ISAS),test-$(isa).c)

GENERATED_FILES += $(foreach isa,$(ISAS),debian/$(isa).docs)
GENERATED_FILES += $(foreach isa,$(ISAS),debian/$(isa).lintian-overrides)
GENERATED_FILES += $(foreach isa,$(ISAS),debian/$(isa).preinst)
GENERATED_FILES += $(foreach isa,$(ISAS),debian/$(isa).templates)
GENERATED_FILES += $(TEST_SOURCES)
ALL_GENERATED_FILES += $(GENERATED_FILES) debian/control
ALL_BINARIES = $(TEST_BINARIES) $(QEMU_BINARIES)

INPUT_FILES = $(wildcard debian/*.in)

CFLAGS ?=
CFLAGS += -Wall
CFLAGS += $(shell cat isa-list | sed -e 's/^Name: /Name: test-/' | grep $@ -A3 | grep '^CFLAGS:' | cut -d ' ' -f2-)

all: $(TEST_BINARIES)
	@:

clean:
	rm -f $(GENERATED_FILES)
	rm -f $(ALL_BINARIES)
	rm -f .last-refresh

install:
	mkdir -p $(DESTDIR)/$(archlibexecdir)/isa-support
	for bin in $(TEST_BINARIES); do $(INSTALL) $$bin $(DESTDIR)/$(archlibexecdir)/isa-support; done
	for bin in $(QEMU_BINARIES); do if test -e $$bin; then $(INSTALL) $$bin $(DESTDIR)/$(archlibexecdir)/isa-support; fi; done

refresh: $(ALL_GENERATED_FILES) $(TEST_SOURCES)
	@:

$(GENERATED_FILES): .last-refresh
	@:

.last-refresh: refresh-package $(INPUT_FILES)
	./refresh-package
	touch $@

.PHONY: all clean refresh
