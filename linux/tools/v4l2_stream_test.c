#include <errno.h>
#include <fcntl.h>
#include <linux/videodev2.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/select.h>
#include <unistd.h>
struct buf { void *p; size_t n; };
static int xc(int f,unsigned long r,void*a){int z;do{z=ioctl(f,r,a);}while(z<0&&errno==EINTR);return z;}
int main(int ac,char**av){const char*d=ac>1?av[1]:"/dev/video0";int f=open(d,O_RDWR|O_NONBLOCK);if(f<0){perror("open");return 1;}struct v4l2_format fmt;memset(&fmt,0,sizeof fmt);fmt.type=V4L2_BUF_TYPE_VIDEO_CAPTURE;fmt.fmt.pix.width=640;fmt.fmt.pix.height=480;fmt.fmt.pix.pixelformat=V4L2_PIX_FMT_MJPEG;fmt.fmt.pix.field=V4L2_FIELD_ANY;if(xc(f,VIDIOC_S_FMT,&fmt)<0){perror("S_FMT");return 2;}printf("format accepted: %ux%u fourcc=%c%c%c%c\n",fmt.fmt.pix.width,fmt.fmt.pix.height,fmt.fmt.pix.pixelformat&255,(fmt.fmt.pix.pixelformat>>8)&255,(fmt.fmt.pix.pixelformat>>16)&255,(fmt.fmt.pix.pixelformat>>24)&255);struct v4l2_requestbuffers rb;memset(&rb,0,sizeof rb);rb.count=4;rb.type=fmt.type;rb.memory=V4L2_MEMORY_MMAP;if(xc(f,VIDIOC_REQBUFS,&rb)<0){perror("REQBUFS");return 3;}struct buf b[4];for(unsigned i=0;i<rb.count;i++){struct v4l2_buffer q;memset(&q,0,sizeof q);q.type=fmt.type;q.memory=V4L2_MEMORY_MMAP;q.index=i;if(xc(f,VIDIOC_QUERYBUF,&q)<0){perror("QUERYBUF");return 4;}b[i].n=q.length;b[i].p=mmap(NULL,q.length,PROT_READ|PROT_WRITE,MAP_SHARED,f,q.m.offset);if(b[i].p==MAP_FAILED){perror("mmap");return 5;}if(xc(f,VIDIOC_QBUF,&q)<0){perror("QBUF");return 6;}}enum v4l2_buf_type t=fmt.type;if(xc(f,VIDIOC_STREAMON,&t)<0){perror("STREAMON");return 7;}puts("STREAMON succeeded; waiting 8 seconds for first frame...");fd_set s;FD_ZERO(&s);FD_SET(f,&s);struct timeval tv={8,0};int n=select(f+1,&s,NULL,NULL,&tv);if(n<0){perror("select");return 8;}if(n==0){puts("RESULT: no frame became ready within 8 seconds");return 9;}struct v4l2_buffer q;memset(&q,0,sizeof q);q.type=t;q.memory=V4L2_MEMORY_MMAP;if(xc(f,VIDIOC_DQBUF,&q)<0){perror("DQBUF");return 10;}printf("RESULT: received frame index=%u bytes=%u flags=0x%x sequence=%u\n",q.index,q.bytesused,q.flags,q.sequence);xc(f,VIDIOC_STREAMOFF,&t);for(unsigned i=0;i<rb.count;i++)munmap(b[i].p,b[i].n);close(f);return q.bytesused?0:11;}
