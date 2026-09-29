CXX := g++
CXXFLAGS := -Wall -O2 $(shell pkg-config --cflags gtk+-3.0)
LDFLAGS := $(shell pkg-config --libs gtk+-3.0)

BUILD_DIR := build
RELEASE_DIR := $(BUILD_DIR)/release
SRC_DIR := src

TARGET := $(RELEASE_DIR)/AutoClicker
SRC := $(SRC_DIR)/app.cpp
OBJ := $(BUILD_DIR)/app.o
COMPILE_CMD := $(BUILD_DIR)/compile_commands.json

all:
	@mkdir -p $(BUILD_DIR)
	@if command -v bear >/dev/null 2>&1; then \
		echo "bear found, generate compile_commands.json using bear..."; \
		bear --output $(COMPILE_CMD) -- make build_app; \
	else \
		echo "Warning: bear not installed. Skip generate compile_commands.json..."; \
		make build_app; \
	fi

build_app: prep $(TARGET)

prep:
	@mkdir -p $(RELEASE_DIR)

$(TARGET): $(OBJ)
	$(CXX) -o $@ $^ $(LDFLAGS)
	@echo "Built AutoClicker at $(TARGET)"

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all build_app prep clean
