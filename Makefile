CXX      ?= g++
PREFIX   ?= /usr/local
CXXFLAGS ?= -O2
LOUVRE_CFLAGS := $(shell pkg-config --cflags cz-louvre 2>/dev/null)
LOUVRE_LIBS   := $(shell pkg-config --libs cz-louvre fontconfig 2>/dev/null)

.PHONY: all check check-shim generate install uninstall clean
all: build/libvolcan.so include/volcan.h

build/volcan_shim.cpp: lib/shim.hcs tools/extract_shim.py
	@mkdir -p build
	python3 tools/extract_shim.py lib/shim.hcs $@

include/volcan.h: lib/shim.hcs tools/gen_header.py tools/shim_protos.py
	python3 tools/gen_header.py

build/libvolcan.so: build/volcan_shim.cpp
	$(CXX) -std=c++20 -fPIC -shared $(CXXFLAGS) $(LOUVRE_CFLAGS) $< -o $@ $(LOUVRE_LIBS)

# Testy bez Louvre i bez zbudowanej biblioteki. Testy kodu HackerScript uruchamiaja prawdziwy
# hackerc (HACKERC=/sciezka lub PATH); bez niego sa pomijane, chyba ze REQUIRE_HACKERC=1.
check:
	python3 tools/test_layout.py
	python3 tools/guards.py
	python3 tools/check_abi.py
	python3 tools/check_abi_snapshot.py $(if $(STRICT_ABI),--strict,)
	python3 tests/test_abi_snapshot.py
	python3 tools/check_h_externs.py
	python3 tests/test_standalone.py
	python3 tests/test_bindings.py
	python3 tests/test_security.py
	python3 tests/run_hcs_tests.py $(if $(REQUIRE_HACKERC),--require,)

# Kompilacja shima na prawdziwych naglowkach Louvre (klonuje zaleznosci do build/deps).
check-shim:
	./tools/syntax_check_shim.sh

# Regeneracja plikow wyprowadzonych z lib/shim.hcs.
generate:
	python3 tools/guards.py --apply
	python3 tools/gen_ffi.py
	python3 tools/gen_header.py
	python3 tools/gen_bindings.py
	python3 tools/check_abi_snapshot.py --update

install: all
	install -Dm755 build/libvolcan.so $(DESTDIR)$(PREFIX)/lib/libvolcan.so
	install -Dm644 include/volcan.h $(DESTDIR)$(PREFIX)/include/volcan.h
	sed 's|@PREFIX@|$(PREFIX)|' native/volcan.pc.in > build/volcan.pc
	install -Dm644 build/volcan.pc $(DESTDIR)$(PREFIX)/lib/pkgconfig/volcan.pc

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/lib/libvolcan.so $(DESTDIR)$(PREFIX)/include/volcan.h $(DESTDIR)$(PREFIX)/lib/pkgconfig/volcan.pc

clean:
	rm -rf build
