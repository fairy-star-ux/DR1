#include "gps.h"
#include <stdio.h>
#include <unistd.h>
#include <pthread.h>

int main(void) {
    pthread_t tid;
    if (gps_init() != 0) return 2;
    if (pthread_create(&tid, NULL, gps_thread_func, NULL) != 0) return 3;
    sleep(5);
    float lat, lon; long ts;
    int ok = gps_get_position(&lat, &lon, &ts);
    printf("GPS_RESULT valid=%d lat=%.6f lon=%.6f ts=%ld\n", ok == 0, lat, lon, ts);
    gps_deinit();
    pthread_join(tid, NULL);
    return ok == 0 ? 0 : 4;
}
