.DEFAULT_GOAL = app

ifdef SHARE
SO = -so
CFLAGS  += -fPIC -D_SHARE=1
LDFLAGS += -rdynamic -shared -fPIC -Wl,--no-undefined -lz
endif

ifdef CONFIG_ENABLE_BRANCH_TRACE
CFLAGS  += -fPIC
endif

WORK_DIR  = $(shell pwd)
BUILD_DIR = $(WORK_DIR)/build

INC_DIR += $(WORK_DIR)/include $(NEMU_HOME)/lib-include
XINC_DIR = $(INC_DIR) $(WORK_DIR)/resource
OBJ_DIR  = $(BUILD_DIR)/obj-$(NAME)$(SO)
BINARY   = $(BUILD_DIR)/$(NAME)$(SO)

CC ?= gcc
CXX = g++

CCACHE := $(if $(shell which ccache),ccache,)

# Compilation flags
CC := $(CCACHE) $(CC)
LD := $(CCACHE) $(CXX)
INCLUDES = $(addprefix -I, $(INC_DIR))
XINCLUDES = $(addprefix -I, $(XINC_DIR))

ifdef CONFIG_ENABLE_BRANCH_TRACE
$(shell swig -python -c++ -Iinclude  -o src/base/branch_trace_wrapper.cpp include/branch_trace.i)
PYINCLUDE = $(shell python3-config --includes)
endif

CFLAGS  := -O2 -MMD -Wall -Werror $(INCLUDES) $(CFLAGS)
CXXFLAGS  := -O2 -MMD -Wall -Werror --std=c++17 $(XINCLUDES) $(PYINCLUDE) $(CFLAGS)
LDFLAGS := -O2 $(LDFLAGS)
# filesystem
ifndef SHARE
LDFLAGS += -lstdc++fs -lstdc++ -lm
endif

COBJS = $(SRCS:%.c=$(OBJ_DIR)/%.o)
XOBJS = $(XSRCS:%.cpp=$(OBJ_DIR)/%.opp)

ifndef SHARE
OBJS = $(COBJS) $(XOBJS)
else
OBJS = $(COBJS) $(XOBJS)
endif

ifdef CONFIG_MEM_COMPRESS
LDFLAGS += -lzstd
endif

# Compilation patterns
$(OBJ_DIR)/%.o: %.c
	@echo + CC $<
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) $(SO_CFLAGS) -c -o $@ $<
	@$(CC) $(CFLAGS) -E $(SO_CFLAGS) -c -o $@.c $<
	$(call call_fixdep, $(@:.o=.d), $@)

$(OBJ_DIR)/%.opp: %.cpp
	@echo + CXX $<
	@mkdir -p $(dir $@)
	@$(CXX) $(CXXFLAGS) -c -o $@ $<
	$(call call_fixdep, $(@:.opp=.d), $@)

# Dependencies
ifndef SHARE
-include $(COBJS:.o=.d) $(XOBJS:.opp=.d)
else
-include $(COBJS:.o=.d)
endif

# Some convenient rules

.PHONY: app clean

app: $(BINARY) BRPYTHON

$(BINARY): $(OBJS) $(LIBS)
	@echo + $(LD) $@
	@$(LD) -o $@ $(OBJS) $(LDFLAGS) $(LIBS)

ifdef CONFIG_ENABLE_BRANCH_TRACE
BRPYTHON: $(OBJS) $(LIBS) $(BINARY)
	mkdir -p $(BUILD_DIR)/NemuBR
	mv src/base/NemuBR.py $(BUILD_DIR)/NemuBR/__init__.py
	@$(LD) -o $(BUILD_DIR)/NemuBR/_NemuBR.so $(OBJS) $(LDFLAGS) -shared -rdynamic -fPIC -lz $(LIBS)
endif

staticlib: $(BUILD_DIR)/lib$(NAME).a

$(BUILD_DIR)/lib$(NAME).a: $(OBJS) $(LIBS)
	@echo + AR $@
	@ar rcs $(BUILD_DIR)/lib$(NAME).a $(OBJS) $(LIBS)

clean:
	-rm -rf $(BUILD_DIR)
