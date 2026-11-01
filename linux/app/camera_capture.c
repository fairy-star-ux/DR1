#include <errno.h>
#include <fcntl.h>
#include <linux/videodev2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/select.h>
#include <unistd.h>

struct buf { void *p; size_t n; };
static int xioctl(int fd, unsigned long r, void *a) { int x; do x=ioctl(fd,r,a); while(x<0&&errno==EINTR); return x; }
int main(int argc,char **argv){
 const char *dev=argc>1?argv[1]:"/dev/video0", *out=argc>2?argv[2]:"/tmp/camera.jpg";
 int fd=open(dev,O_RDWR|O_NONBLOCK); if(fd<0){perror("open");return 1;}
 struct v4l2_capability cap; memset(&cap,0,sizeof cap); if(xioctl(fd,VIDIOC_QUERYCAP,&cap)<0){perror("QUERYCAP");return 1;}
 printf("%s: %s, caps=0x%x\n",dev,cap.card,cap.capabilities);
 struct v4l2_format f; memset(&f,0,sizeof f); f.type=V4L2_BUF_TYPE_VIDEO_CAPTURE; f.fmt.pix.width=640; f.fmt.pix.height=480; f.fmt.pix.pixelformat=V4L2_PIX_FMT_MJPEG; f.fmt.pix.field=V4L2_FIELD_ANY;
 if(xioctl(fd,VIDIOC_S_FMT,&f)<0){perror("S_FMT");return 1;} printf("format %ux%u fourcc=%c%c%c%c size=%u\n",f.fmt.pix.width,f.fmt.pix.height,f.fmt.pix.pixelformat&255,(f.fmt.pix.pixelformat>>8)&255,(f.fmt.pix.pixelformat>>16)&255,(f.fmt.pix.pixelformat>>24)&255,f.fmt.pix.sizeimage);
 struct v4l2_control ctrl; memset(&ctrl,0,sizeof ctrl); ctrl.id=V4L2_CID_EXPOSURE_AUTO; ctrl.value=V4L2_EXPOSURE_APERTURE_PRIORITY; if(xioctl(fd,VIDIOC_S_CTRL,&ctrl)<0)perror("set auto exposure"); memset(&ctrl,0,sizeof ctrl); ctrl.id=V4L2_CID_BACKLIGHT_COMPENSATION; ctrl.value=3; if(xioctl(fd,VIDIOC_S_CTRL,&ctrl)<0)perror("set backlight compensation");
 struct v4l2_requestbuffers rb; memset(&rb,0,sizeof rb); rb.count=4; rb.type=f.type; rb.memory=V4L2_MEMORY_MMAP; if(xioctl(fd,VIDIOC_REQBUFS,&rb)<0){perror("REQBUFS");return 1;}
 struct buf *b=calloc(rb.count,sizeof *b); for(unsigned i=0;i<rb.count;i++){struct v4l2_buffer q; memset(&q,0,sizeof q);q.type=f.type;q.memory=V4L2_MEMORY_MMAP;q.index=i;if(xioctl(fd,VIDIOC_QUERYBUF,&q)<0){perror("QUERYBUF");return 1;}b[i].n=q.length;b[i].p=mmap(NULL,q.length,PROT_READ|PROT_WRITE,MAP_SHARED,fd,q.m.offset);if(b[i].p==MAP_FAILED){perror("mmap");return 1;}if(xioctl(fd,VIDIOC_QBUF,&q)<0){perror("QBUF");return 1;}}
 enum v4l2_buf_type type=f.type; if(xioctl(fd,VIDIOC_STREAMON,&type)<0){perror("STREAMON");return 1;}
 FILE *fp=NULL; int good_frames=0; for(int tries=0;tries<60;tries++){fd_set s;FD_ZERO(&s);FD_SET(fd,&s);struct timeval tv={2,0};if(select(fd+1,&s,NULL,NULL,&tv)<=0)continue;struct v4l2_buffer q;memset(&q,0,sizeof q);q.type=type;q.memory=V4L2_MEMORY_MMAP;if(xioctl(fd,VIDIOC_DQBUF,&q)<0){if(errno==EAGAIN)continue;perror("DQBUF");break;}printf("frame %u bytes\n",q.bytesused);if(q.bytesused>100){good_frames++; if(good_frames>=12){fp=fopen(out,"wb");if(fp){fwrite(b[q.index].p,1,q.bytesused,fp);fclose(fp);printf("saved %s\n",out);}}}xioctl(fd,VIDIOC_QBUF,&q);if(fp)break;}
 xioctl(fd,VIDIOC_STREAMOFF,&type);for(unsigned i=0;i<rb.count;i++)munmap(b[i].p,b[i].n);close(fd);return fp?0:2;
}
