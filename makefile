.DEFAULT_GOAL := default

default:
	zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux
