CXX ?= g++
CXXFLAGS ?= -O3 -Wall -Wextra
WAYLAND_LIBS = $(shell pkg-config --cflags --libs wayland-client 2>/dev/null)

BUILD_DIR = build
SRC_DIR = src

TARGETS = $(BUILD_DIR)/show-keybinds $(BUILD_DIR)/navbar-hover $(BUILD_DIR)/navbar-watcher $(BUILD_DIR)/hypr-nice $(BUILD_DIR)/eject-forbidden

.PHONY: all clean preflight

all: preflight
	$(MAKE) $(TARGETS)

preflight:
	@command -v $(CXX) >/dev/null 2>&1 || { echo "ERROR: C++ compiler '$(CXX)' is missing." >&2; exit 1; }
	@command -v pkg-config >/dev/null 2>&1 || { echo "ERROR: pkg-config is missing." >&2; exit 1; }
	@pkg-config --exists wayland-client || { echo "ERROR: wayland-client development files are missing." >&2; exit 1; }
	@test -f /usr/include/nlohmann/json.hpp || { echo "ERROR: /usr/include/nlohmann/json.hpp is missing; install the Arch package 'nlohmann-json'." >&2; exit 1; }

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/show-keybinds: preflight $(SRC_DIR)/show-keybinds.cpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -o $@ $(SRC_DIR)/show-keybinds.cpp

$(BUILD_DIR)/navbar-hover: preflight $(SRC_DIR)/navbar-hover.cpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -o $@ $(SRC_DIR)/navbar-hover.cpp $(WAYLAND_LIBS)

$(BUILD_DIR)/navbar-watcher: preflight $(SRC_DIR)/navbar-watcher.cpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -o $@ $(SRC_DIR)/navbar-watcher.cpp $(WAYLAND_LIBS)

$(BUILD_DIR)/hypr-nice: preflight $(SRC_DIR)/hypr-nice.cpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -o $@ $(SRC_DIR)/hypr-nice.cpp

$(BUILD_DIR)/eject-forbidden: preflight $(SRC_DIR)/eject-forbidden.cpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -o $@ $(SRC_DIR)/eject-forbidden.cpp

clean:
	rm -rf $(BUILD_DIR)
