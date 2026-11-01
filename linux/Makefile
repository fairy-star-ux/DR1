CC = aarch64-linux-gnu-gcc
CFLAGS ?= -O2 -Wall -Wextra
BUILD ?= build
TOOLS = camera_capture v4l2_stream_test v4l2_probe v4l2_controls motor_test gps_probe
.PHONY: all clean
all: $(addprefix $(BUILD)/,$(TOOLS))
$(BUILD):
	mkdir -p $@
$(BUILD)/camera_capture: app/camera_capture.c | $(BUILD)
	$(CC) $(CFLAGS) $< -o $@
$(BUILD)/motor_test: tools/motor_test.c tools/boat_common.h | $(BUILD)
	$(CC) $(CFLAGS) -D_GNU_SOURCE -Itools $< -o $@
$(BUILD)/gps_probe: tools/gps_probe.c tools/gps.c tools/gps.h tools/boat_common.h | $(BUILD)
	$(CC) $(CFLAGS) -D_GNU_SOURCE -pthread -Itools tools/gps_probe.c tools/gps.c -o $@
$(BUILD)/%: tools/%.c | $(BUILD)
	$(CC) $(CFLAGS) -D_GNU_SOURCE $< -o $@
clean:
	rm -f $(addprefix $(BUILD)/,$(TOOLS))
