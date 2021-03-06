include config.mk

default:  libroutez.so examples/testgraph \
	python/libroutez/tripgraph.py python/libroutez/_tripgraph.so \
	ruby/routez.so

include install.mk

# Always always compile with fPIC
CFLAGS += -fPIC
CXXFLAGS += -fPIC -I/usr/include/python2.6 -I/usr/lib/ruby/1.8/i486-linux

# libroutez should be compiled as a shared library by default
ifeq (${OS},MACOS)
	LDFLAGS += -dynamiclib
else
	LDFLAGS += -shared
endif

config.mk:
	@echo "Please run ./configure. Stop."
	@exit 1

%.o: %.cc 
	g++ $< -c -o $@ $(CXXFLAGS) $(PYTHON_CFLAGS) $(RUBY_CFLAGS) -I./include -g
	@g++ $< -MM $(CXXFLAGS) $(PYTHON_CFLAGS) $(RUBY_CFLAGS) -I./include > $*.d
	@mv -f $*.d $*.d.tmp
	@sed -e 's|.*:|$*.o:|' < $*.d.tmp > $*.d
	@sed -e 's/.*://' -e 's/\\$$//' < $*.d.tmp | fmt -1 | \
	  sed -e 's/^ *//' -e 's/$$/:/' >> $*.d
	@rm -f $*.d.tmp

TRIPGRAPH_OBJECTS=lib/tripgraph.o lib/trippath.o lib/tripstop.o lib/serviceperiod.o

# libroutez: the main library
libroutez.so: $(TRIPGRAPH_OBJECTS)
	g++ $(TRIPGRAPH_OBJECTS) $(LDFLAGS) -o libroutez.so -fPIC -g

# python bindings
python/libroutez/tripgraph.py python/libroutez/tripgraph_wrap_py.cc: tripgraph.i
	swig -classic -c++ -python -I./include -outdir python/libroutez -o python/libroutez/tripgraph_wrap_py.cc $<
python/libroutez/_tripgraph.so: libroutez.so python/libroutez/tripgraph_wrap_py.o
	g++ -o $@ python/libroutez/tripgraph_wrap_py.o libroutez.so $(LDFLAGS) $(PYTHON_LDFLAGS) -fPIC

# ruby bindings
ruby/routez_wrap_rb.cc: routez.i tripgraph.i 
	swig -c++ -ruby -I./include  -o $@ $<

ruby/routez.so: libroutez.so ruby/routez_wrap_rb.o
	g++ -o ruby/routez.so ruby/routez_wrap_rb.o libroutez.so $(LDFLAGS) $(RUBY_LDFLAGS) -I./include -fPIC

# stupid test program
examples/testgraph: examples/testgraph.o libroutez.so
	g++ $< -o $@ libroutez.so -fPIC -g -I./include

# unit test suite
TEST_OBJS=t/tripgraph.t.o t/tripstop.t.o t/all.t.o
t/all.t: $(TEST_OBJS) libroutez.so
	g++ $(TEST_OBJS) -o $@ libroutez.so -fPIC -g

.PHONY: test
test: t/all.t
	LD_LIBRARY_PATH=$(PWD) valgrind --tool=memcheck --suppressions=t/boost.supp t/all.t

clean:
	rm -f *.so lib/*.o python/*.pyc */*.pyc examples/testgraph \
	python/libroutez/_tripgraph.so python/libroutez/tripgraph.py \
	python/libroutez/tripgraph_wrap_py.cc python/libroutez/*.o \
	ruby/routez.so ruby/*.o ruby/routez_wrap_rb.cc \
	t/*.o t/all.t *.d

-include $(TRIPGRAPH_OBJECTS:.o=.d)
