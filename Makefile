TARGET=$$HOME/.local/bin

install: sdfm.sh
	ln -s $$(realpath sdfm.sh) $(TARGET)/sdfm
