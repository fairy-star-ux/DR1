#include <errno.h>
#include <fcntl.h>
#include <linux/videodev2.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>
int main(int argc,char **argv){const char*d=argc>1?argv[1]:"/dev/video0";int f=open(d,O_RDWR);if(f<0){perror("open");return 1;}struct v4l2_capability c={0};ioctl(f,VIDIOC_QUERYCAP,&c);printf("%s card=%s caps=0x%x\n",d,c.card,c.capabilities);struct v4l2_fmtdesc x={0};x.type=V4L2_BUF_TYPE_VIDEO_CAPTURE;for(x.index=0;ioctl(f,VIDIOC_ENUM_FMT,&x)==0;x.index++)printf("fmt %d fourcc=%c%c%c%c desc=%s\n",x.index,x.pixelformat&255,(x.pixelformat>>8)&255,(x.pixelformat>>16)&255,(x.pixelformat>>24)&255,x.description);struct v4l2_frmsizeenum s={0};for(s.pixel_format=V4L2_PIX_FMT_MJPEG;s.index<20;s.index++)if(ioctl(f,VIDIOC_ENUM_FRAMESIZES,&s)==0)printf("mjpg size %u %ux%u\n",s.index,s.discrete.width,s.discrete.height);close(f);}
