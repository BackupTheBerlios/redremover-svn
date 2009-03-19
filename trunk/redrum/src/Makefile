CFLAGS	+= -g -Wall
LDFLAGS	+= -g -Wl,--gc-sections -Wl,--print-gc-sections


############################################################

all:

tests:
	./run-tests
.PHONY: tests


############################################################
#
# Example
#

EX	:= example/

EXBIN := $(EX)/test-prog
EXSRC := $(EXBIN).c
EXASM := $(EXBIN).s

EXBIN_T := $(EX)/t3
EXASM_T := $(EXBIN_T).s


SUBST_DIR := $(EX)/subst.d
SUBST_SRC = $(wildcard $(SUBST_DIR)/*.s)
SUBST_OBJ = $(SUBST_SRC:%.s=%.o)

SUBST_A	:=	$(SUBST_DIR)/redrum.a

all: $(EXASM) $(EXBIN) $(EXBIN_T) $(EXBIN_T).deass $(EXBIN).deass
		size $(EXBIN) $(EXBIN_T)
		codiff -V $(EXBIN) $(EXBIN_T)


$(EXBIN): $(EXBIN).o
$(EXBIN).o: $(EXSRC)
$(EXASM): $(EXSRC)
		$(CC) -S -o $@ $<

$(SUBST_A): $(SUBST_SRC)
		$(MAKE) -C $(SUBST_DIR) -f `pwd`/../doc/redrum-Makefile

%.deass: %
		objdump -d $< > $@

# $(EXASM_T): $(EXASM) 
# 		PERL5LIB=. ./rr-translate.pl $< > $@
# $(EXBIN).o: $(EXASM_T)
# 		$(CC) -c -o $@ $<
# 

$(EXBIN_T): $(EXSRC) rr-translate.pl $(SUBST_A)
	ASM_SUBST_DIR=$(shell pwd)/$(SUBST_DIR) $(CC) $(LDFLAGS) $(CFLAGS) -L$(SUBST_DIR) -lredrum -o $@ $<
	
ex-a: $(EXBIN) rr-analyse.pl
		rm $(SUBST_DIR)/saved-*
		./rr-analyse.pl -m1 -M48 -t2 -o $(SUBST_DIR) $<

clean:
		rm $(EX)/*.deass $(EX)/*.s $(EX)/*.o $(EXBIN) $(EXBIN_T) 2> /dev/null || true

