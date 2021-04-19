OBJS = $(shell ls src | awk '{ print "lib/" $$1 } ' | sed -e s/.coffee/.js/g)

CFF = ../node_modules/.bin/coffee
CFFFLAGS = --bare --no-header

build: $(OBJS)
	@ echo "[ build lib ... ok ]"

lib/%.js: src/%.coffee
	$(CFF) $(CFFFLAGS) -c -o $(shell realpath $@) $(shell realpath $<)

clean:
	rm lib/*.js

