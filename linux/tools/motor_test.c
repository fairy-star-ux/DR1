#include "boat_common.h"

#define MOTOR_PORT_DEFAULT "/dev/ttyUSB0"
#define MOTOR_BAUD B115200
static int open_motor(const char *port) {
    int fd = open(port, O_RDWR | O_NOCTTY | O_SYNC);
    if (fd < 0) return -1;
    struct termios t;
    if (tcgetattr(fd, &t) != 0) { close(fd); return -1; }
    cfsetispeed(&t, MOTOR_BAUD);
    cfsetospeed(&t, MOTOR_BAUD);
    t.c_cflag = (t.c_cflag & ~CSIZE) | CS8;
    t.c_cflag |= CLOCAL | CREAD;
    t.c_cflag &= ~(PARENB | CSTOPB | CRTSCTS);
    t.c_iflag &= ~(IXON | IXOFF | IXANY | INLCR | ICRNL | IGNCR);
    t.c_lflag = 0;
    t.c_oflag = 0;
    t.c_cc[VMIN] = 0;
    t.c_cc[VTIME] = 5;
    tcflush(fd, TCIOFLUSH);
    if (tcsetattr(fd, TCSANOW, &t) != 0) { close(fd); return -1; }
    return fd;
}

static int send_cmd(int fd, const char *cmd) {
    size_t n = strlen(cmd), sent = 0;
    while (sent < n) {
        ssize_t w = write(fd, cmd + sent, n - sent);
        if (w < 0) { if (errno == EINTR) continue; return -1; }
        sent += (size_t)w;
    }
    tcdrain(fd);
    printf("sent: %s", cmd);
    return 0;
}

int main(void) {
    const char *port = getenv("MOTOR_SERIAL_PORT");
    if (!port || !*port) port = MOTOR_PORT_DEFAULT;
    int fd = open_motor(port);
    if (fd < 0) { fprintf(stderr, "cannot open %s: %s\n", port, strerror(errno)); return 1; }
    printf("motor test on %s, pwm=3000 on channels 1 and 3\n", port);
    if (send_cmd(fd, "$mtype:4#\r\n") < 0) return 2;
    sleep(1);
    if (send_cmd(fd, "$deadzone:1650#\r\n") < 0) return 2;
    sleep(1);
    /* Two-wheel test: channels 1 and 3 at PWM 3000. */
    if (send_cmd(fd, "$pwm:3000,0,3000,0#\r\n") < 0) return 2;
    sleep(3);
    if (send_cmd(fd, "$pwm:0,0,0,0#\r\n") < 0) return 2;
    close(fd);
    puts("motor test complete; stop command sent");
    return 0;
}
