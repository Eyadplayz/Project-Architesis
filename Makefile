#-------------------------------------------------------------------------------
.SUFFIXES:
#-------------------------------------------------------------------------------

ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>/devkitpro")
endif

TOPDIR ?= $(CURDIR)

include $(DEVKITPRO)/wut/share/wut_rules

WUMS_ROOT := $(DEVKITPRO)/wums
#-------------------------------------------------------------------------------
# TARGET is the name of the output
# BUILD is the directory where object files & intermediate files will be placed
# SOURCES is a list of directories containing source code
# DATA is a list of directories containing data files
# INCLUDES is a list of directories containing header files
#-------------------------------------------------------------------------------
TARGET		:=	NetworkInstaller
BUILD		:=	build
SOURCES		:=	src \
				src/gui \
				src/fs \
				src/input \
				src/menu \
				src/resources \
				src/patch \
				src/system \
				src/system/video \
				src/utils
DATA		:=	data \
				data/images \
				data/sounds \
				data/fonts
INCLUDES	:=	source

#-------------------------------------------------------------------------------
# options for code generation
#-------------------------------------------------------------------------------
+CFLAGS :=  -g -Wall -O2 -ffunction-sections `$(PREFIX)pkg-config --cflags SDL2_mixer SDL2_ttf SDL2_image` \
			$(MACHDEP)

CFLAGS	+=	$(INCLUDE) -D__WIIU__ -D__WUT__ -D__LOGGING__ -D__NONAROMA__ -D__NONCHANNEL__ 

CXXFLAGS	:= $(CFLAGS) -std=c++20 -D__LOGGING__  -D__NONAROMA__ -D__NONCHANNEL__ 

ASFLAGS	:=	-g $(ARCH) -mregnames
LDFLAGS	=	-g $(ARCH) $(RPXSPECS) -Wl,-Map,$(notdir $*.map)

LIBS   :=   `$(PREFIX)pkg-config --libs SDL2_mixer SDL2_ttf SDL2_image`
Q := @
MAKEFLAGS += --no-print-directory
#-------------------------------------------------------------------------------
# list of directories containing libraries, this must be the top level
# containing include and lib
#-------------------------------------------------------------------------------
LIBDIRS	:= $(PORTLIBS) $(WUT_ROOT) $(WUMS_ROOT) $(CURDIR)

#-------------------------------------------------------------------------------
# no real need to edit anything past this point unless you need to add additional
# rules for different file extensions
#-------------------------------------------------------------------------------
ifneq ($(BUILD),$(notdir $(CURDIR)))
#-------------------------------------------------------------------------------

export OUTPUT	:=	$(CURDIR)/$(TARGET)
export TOPDIR	:=	$(CURDIR)

export VPATH	:=	$(foreach dir,$(SOURCES),$(CURDIR)/$(dir)) \
			$(foreach dir,$(DATA),$(CURDIR)/$(dir))

export DEPSDIR	:=	$(CURDIR)/$(BUILD)
export OBJCOPY	:=	$(PREFIX)objcopy
FILELIST	:=	$(shell bash ./filelist.sh)
CFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.c)))
CPPFILES	:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.cpp)))
SFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.S)))
LINKFILES	:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.ld)))
BINFILES	:=	$(foreach dir,$(DATA),$(notdir $(wildcard $(dir)/*.*)))

#-------------------------------------------------------------------------------
# use CXX for linking C++ projects, CC for standard C
#-------------------------------------------------------------------------------
ifeq ($(strip $(CPPFILES)),)
#-------------------------------------------------------------------------------
	export LD	:=	$(CC)
#-------------------------------------------------------------------------------
else
#-------------------------------------------------------------------------------
	export LD	:=	$(CXX)
#-------------------------------------------------------------------------------
endif
#-------------------------------------------------------------------------------

export OFILES_BIN	:=	$(addsuffix .o,$(BINFILES)) #$(SFILES:.ld=.elf)
export OFILES_SRC	:=	$(CPPFILES:.cpp=.o) $(CFILES:.c=.o) $(SFILES:.S=.o) 
export OFILES 	:=	$(OFILES_BIN) $(OFILES_SRC) 
export HFILES_BIN	:=	$(addsuffix .h,$(subst .,_,$(BINFILES))) #$(addsuffix .ld,$(subst .ld,,$(LINKFILES)))

export INCLUDE	:=	$(foreach dir,$(INCLUDES),-I$(CURDIR)/$(dir)) \
			$(foreach dir,$(LIBDIRS),-I$(dir)/include) \
			-I$(CURDIR)/$(BUILD)

export LIBPATHS	:=	$(foreach dir,$(LIBDIRS),-L$(dir)/lib)

.PHONY: $(BUILD) clean all

#-------------------------------------------------------------------------------
all: $(BUILD)

$(BUILD):
	@[ -d $@ ] || mkdir -p $@
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile

#-------------------------------------------------------------------------------
clean:
	@echo clean ...
	@rm -fr $(BUILD) $(TARGET).rpx $(TARGET).elf

#-------------------------------------------------------------------------------
else
.PHONY:	all

DEPENDS	:=	$(OFILES:.o=.d) 

#-------------------------------------------------------------------------------
# main targets
#-------------------------------------------------------------------------------

all	:	 $(OUTPUT).rpx


$(OUTPUT).rpx	:	$(OUTPUT).elf
$(OUTPUT).elf	:   $(OFILES)

$(OFILES_SRC)	: $(HFILES_BIN)

#-------------------------------------------------------------------------------
# you need a rule like this for each extension you use as binary data
#-------------------------------------------------------------------------------
%.bin.o	%_bin.h :	%.bin
#-------------------------------------------------------------------------------
	@echo $(notdir $<)
	@$(bin2o)

%.png.o	%_png.h :	%.png
	@echo $(notdir $<)
	@$(bin2o)
	
%.jpg.o	%_jpg.h :	%.jpg
	@echo $(notdir $<)
	@$(bin2o)
	
%.ogg.o	%_ogg.h :	%.ogg
	@echo $(notdir $<)
	@$(bin2o)	
	
%.mp3.o	%_mp3.h :	%.mp3
	@echo $(notdir $<)
	@$(bin2o)	
	
%.ttf.o	%_ttf.h :	%.ttf
	@echo $(notdir $<)
	@$(bin2o)	

#---------------------------------------------------------------------------------
%.o: %.S
	@echo $(notdir $<)
	@$(CC) -MMD -MP -MF $(DEPSDIR)/$*.d -x assembler-with-cpp $(ASFLAGS) -c $< -o $@ $(ERROR_FILTER)
#---------------------------------------------------------------------------------
%.elf: %.ld
	@echo $(notdir $<)
	$(Q)$(LD) -n -T $^ $(LDFLAGS) -o ../$(BUILD).elf  $(LIBPATHS) $(LIBS)
-include $(DEPENDS)

#-------------------------------------------------------------------------------
endif
#-------------------------------------------------------------------------------