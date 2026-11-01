#!/usr/bin/env python3
import base64
import json
import os
import re
import select
import mmap
import struct
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import ThreadingMixIn
from urllib.parse import unquote, urlparse

HOST = os.environ.get("WEB_HOST", "0.0.0.0")
PORT = int(os.environ.get("WEB_PORT", "8080"))
MOTOR_PORT = os.environ.get("MOTOR_SERIAL_PORT", "/dev/ttyUSB0")
GPS_PORT = os.environ.get("GPS_SERIAL_PORT", "/dev/ttyUSB1")
VIDEO = os.environ.get("CAMERA_DEVICE", "/dev/video0")
CAPTURE = os.environ.get("CAMERA_CAPTURE", "/usr/local/bin/camera_capture")
PHOTO_DIR = os.environ.get("PHOTO_DIR", "/var/lib/boat-web/photos")
SERVO_BASE_TEXT = os.environ.get("FPGA_SERVO_MMIO_BASE", "").strip()
try:
    SERVO_MMIO_BASE = int(SERVO_BASE_TEXT, 0) if SERVO_BASE_TEXT else None
except ValueError:
    SERVO_MMIO_BASE = None
SERVO_MMIO_SIZE = 4096

state = {
    "motor": [0, 0, 0, 0],
    "gps": {"available": False, "fix": False, "lat": None, "lon": None,
            "speed_knots": None, "time": None, "source": GPS_PORT, "error": None},
    "fpga": {"servo_control": SERVO_MMIO_BASE is not None,
             "ultrasonic_control": SERVO_MMIO_BASE is not None,
             "camera_pan": 90, "camera_tilt": 90, "ultrasonic_angle": 90,
             "ultrasonic_enabled": False,
             "ultrasonic_sweep": False,
             "message": ("AXI 舵机寄存器可写，基地址 0x%X" % SERVO_MMIO_BASE
                         if SERVO_MMIO_BASE is not None else
                         "FPGA_SERVO_MMIO_BASE 尚未配置；启用 AXI GP0 并生成地址映射后再设置")},
    "last_photo": None,
    "motor_error": None,
}
state_lock = threading.Lock()
serial_lock = threading.Lock()
camera_lock = threading.Lock()
last_capture_at = 0.0
servo_lock = threading.Lock()


def servo_mmio_write(offset, value):
    if SERVO_MMIO_BASE is None:
        raise RuntimeError("FPGA 舵机寄存器未映射：需先启用 AXI GP0 并配置 FPGA_SERVO_MMIO_BASE")
    if SERVO_MMIO_BASE & (SERVO_MMIO_SIZE - 1):
        raise RuntimeError("FPGA_SERVO_MMIO_BASE 必须按 4 KiB 对齐")
    fd = os.open("/dev/mem", os.O_RDWR | getattr(os, "O_SYNC", 0))
    try:
        with mmap.mmap(fd, SERVO_MMIO_SIZE, flags=mmap.MAP_SHARED,
                       prot=mmap.PROT_READ | mmap.PROT_WRITE,
                       offset=SERVO_MMIO_BASE) as mm:
            struct.pack_into("<I", mm, offset, value & 0xffffffff)
    finally:
        os.close(fd)


def servo_angle(value, label):
    if isinstance(value, bool) or not isinstance(value, int) or not 0 <= value <= 180:
        raise ValueError(label + "角度必须为 0 到 180 的整数")
    return value


def servo_status_update(**values):
    with state_lock:
        state["fpga"].update(values)
        state["fpga"]["servo_control"] = SERVO_MMIO_BASE is not None
        state["fpga"]["ultrasonic_control"] = SERVO_MMIO_BASE is not None
        state["fpga"]["message"] = ("AXI 舵机寄存器可写，基地址 0x%X" % SERVO_MMIO_BASE
                                     if SERVO_MMIO_BASE is not None else
                                     "FPGA_SERVO_MMIO_BASE 尚未配置；启用 AXI GP0 并生成地址映射后再设置")


def serial_fd(path, baud=115200):
    import termios
    fd = os.open(path, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    attrs = termios.tcgetattr(fd)
    attrs[0] = 0
    attrs[1] = 0
    attrs[2] = termios.CLOCAL | termios.CREAD | termios.CS8
    attrs[3] = 0
    speeds = {9600: termios.B9600, 115200: termios.B115200}
    attrs[4] = attrs[5] = speeds.get(baud, termios.B9600)
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    return fd


def motor_command(values):
    values = [max(-10000, min(10000, int(v))) for v in values]
    command = "$pwm:%d,%d,%d,%d#" % tuple(values)
    try:
        with serial_lock:
            fd = serial_fd(MOTOR_PORT)
            os.write(fd, command.encode("ascii"))
            os.close(fd)
        with state_lock:
            state["motor"] = values
            state["motor_error"] = None
        return True, command
    except Exception as exc:
        with state_lock:
            state["motor_error"] = str(exc)
        return False, str(exc)


def nmea_coord(raw, hemi):
    if not raw:
        return None
    try:
        deg = int(float(raw) // 100)
        minute = float(raw) - deg * 100
        value = deg + minute / 60.0
        return -value if hemi in ("S", "W") else value
    except ValueError:
        return None


def parse_nmea(line):
    line = line.strip()
    if not line.startswith("$"):
        return None
    body = line[1:].split("*", 1)[0]
    fields = body.split(",")
    kind = fields[0][-3:]
    if kind == "RMC" and len(fields) >= 9:
        return {"fix": fields[2] == "A", "lat": nmea_coord(fields[3], fields[4]),
                "lon": nmea_coord(fields[5], fields[6]),
                "speed_knots": float(fields[7]) if fields[7] else None,
                "time": fields[1] or None}
    if kind == "GGA" and len(fields) >= 7:
        return {"fix": fields[6] not in ("", "0"), "lat": nmea_coord(fields[2], fields[3]),
                "lon": nmea_coord(fields[4], fields[5]), "time": fields[1] or None}
    return None


def gps_worker():
    while True:
        try:
            fd = serial_fd(GPS_PORT, 9600)
            with state_lock:
                state["gps"]["available"] = True
                state["gps"]["error"] = None
            buf = b""
            while True:
                ready, _, _ = select.select([fd], [], [], 2.0)
                if not ready:
                    continue
                data = os.read(fd, 512)
                if not data:
                    break
                buf += data
                while b"\n" in buf:
                    raw, buf = buf.split(b"\n", 1)
                    try:
                        item = parse_nmea(raw.decode("ascii", "ignore"))
                    except Exception:
                        item = None
                    if item:
                        with state_lock:
                            state["gps"].update(item)
            os.close(fd)
        except Exception as exc:
            with state_lock:
                state["gps"]["available"] = False
                state["gps"]["error"] = str(exc)
            time.sleep(3)


def json_response(handler, payload, status=200):
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(data)))
    handler.end_headers()
    handler.wfile.write(data)


HTML = r'''<!doctype html><meta charset="utf-8"><title>DR1M90 小船控制台</title>
<style>body{font-family:Arial,sans-serif;max-width:980px;margin:20px auto;padding:0 15px;background:#f4f6f8;color:#18212b}section{background:white;padding:16px;margin:12px 0;border:1px solid #d8dee5;border-radius:6px}button{padding:8px 14px;margin:4px;cursor:pointer}input{width:90px;padding:7px}.row{display:flex;gap:10px;flex-wrap:wrap}.bad{color:#b42318}.ok{color:#067647}img{max-width:320px;max-height:240px;margin:6px;border:1px solid #bbb}</style>
<h1>DR1M90 小船控制台</h1>
<section><h2>两路电机</h2><label>速度：<input id=speed type=range min=0 max=3600 value=3000 oninput="speedv.textContent=this.value"><b id=speedv>3000</b></label><div class=row><button onclick="drive(1)">前进</button><button onclick="drive(-1)">后退</button><button onclick="turn(-1)">左转</button><button onclick="turn(1)">右转</button><button onclick="motor(0,0,0,0)">停止</button></div><p>电机1/电机2 PWM：<input id=p1 type=number value=0><input id=p2 type=number value=0><button onclick="customMotor()">发送</button></p><p id=motor>未发送</p></section>
<section><h2>GPS</h2><pre id=gps>读取中...</pre></section>
<section><h2>摄像头</h2><button onclick="capture()">拍照</button><div id=photos></div></section>
<section><h2>摄像头云台</h2><p>水平角度：<input id=pan type=range min=0 max=180 value=90 oninput="panv.textContent=this.value"><b id=panv>90</b>°　垂直角度：<input id=tilt type=range min=0 max=180 value=90 oninput="tiltv.textContent=this.value"><b id=tiltv>90</b>°</p><button onclick="setPtz()">设置云台角度</button></section>
<section><h2>超声波舵机</h2><p>目标角度：<input id=ua type=range min=0 max=180 value=90 oninput="uav.textContent=this.value"><b id=uav>90</b>°</p><button onclick="setUltrasonic(true,false)">转到指定角度</button><button onclick="setUltrasonic(true,false)">启动并保持角度</button><button onclick="setUltrasonic(true,true)">启动往返扫描</button><button onclick="setUltrasonic(false,false)">停止</button><p id=fpga class=bad>检查中...</p></section>
<script>
async function api(url,opt){let r=await fetch(url,opt),j=await r.json();if(!r.ok)throw Error(j.error||r.status);return j}
async function motor(a,b,c,d){try{let j=await api('/api/motor',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({pwm:[a,b,c,d]})});motorEl.textContent='已发送 '+j.command}catch(e){motorEl.textContent='失败：'+e}}
function sv(){return Number(document.getElementById('speed').value)}
function drive(dir){let v=sv()*dir;motor(v,0,v,0)}
function turn(dir){let v=sv();if(dir<0)motor(0,0,v,0);else motor(v,0,0,0)}
function customMotor(){motor(Number(document.getElementById('p1').value),0,Number(document.getElementById('p2').value),0)}
async function capture(){try{let j=await api('/api/capture',{method:'POST'});loadPhotos();alert('已保存 '+j.file)}catch(e){alert(e)}}
async function setPtz(){try{let j=await api('/api/ptz',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({pan:Number(document.getElementById('pan').value),tilt:Number(document.getElementById('tilt').value)})});fpga.textContent=j.message}catch(e){fpga.textContent='云台控制失败：'+e}}
async function setUltrasonic(enable,sweep){try{let j=await api('/api/ultrasonic',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({enable:enable,sweep:sweep,angle:Number(document.getElementById('ua').value)})});fpga.textContent=j.message}catch(e){fpga.textContent='超声波舵机控制失败：'+e}}
async function refresh(){try{let j=await api('/api/status');gps.textContent=JSON.stringify(j.gps,null,2);fpga.textContent=j.fpga.message;fpga.className=j.fpga.servo_control?'ok':'bad';motorEl.textContent='当前PWM '+j.motor.join(',')+(j.motor_error?'；'+j.motor_error:'')}catch(e){gps.textContent=e}}
async function loadPhotos(){let j=await api('/api/photos');photos.innerHTML=j.files.map(x=>'<img src="/photos/'+encodeURIComponent(x)+'">').join('')||'暂无照片'}
let gps=document.getElementById('gps'),fpga=document.getElementById('fpga'),photos=document.getElementById('photos'),motorEl=document.getElementById('motor');refresh();loadPhotos();setInterval(refresh,2000)
</script>'''


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(fmt % args, flush=True)

    def do_GET(self):
        path = unquote(urlparse(self.path).path)
        if path == "/":
            data = HTML.encode("utf-8")
            self.send_response(200); self.send_header("Content-Type", "text/html; charset=utf-8"); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data); return
        if path == "/api/status":
            with state_lock: payload = dict(state)
            json_response(self, payload); return
        if path == "/api/photos":
            os.makedirs(PHOTO_DIR, exist_ok=True)
            files = sorted((x for x in os.listdir(PHOTO_DIR) if x.lower().endswith((".jpg", ".jpeg"))), reverse=True)
            json_response(self, {"files": files}); return
        if path.startswith("/photos/"):
            name = os.path.basename(path[8:])
            if name != path[8:] or not re.fullmatch(r"[A-Za-z0-9_.-]+", name): self.send_error(404); return
            filename = os.path.join(PHOTO_DIR, name)
            if not os.path.isfile(filename): self.send_error(404); return
            data = open(filename, "rb").read(); self.send_response(200); self.send_header("Content-Type", "image/jpeg"); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data); return
        self.send_error(404)

    def do_POST(self):
        path = urlparse(self.path).path
        try:
            n = int(self.headers.get("Content-Length", "0")); body = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            json_response(self, {"ok": False, "error": "JSON格式错误"}, 400); return
        if path == "/api/motor":
            pwm = body.get("pwm")
            if not isinstance(pwm, list) or len(pwm) != 4: json_response(self, {"ok": False, "error": "pwm必须是4个数"}, 400); return
            ok, detail = motor_command(pwm); json_response(self, {"ok": ok, "command": detail} if ok else {"ok": False, "error": detail}, 200 if ok else 503); return
        if path == "/api/capture":
            os.makedirs(PHOTO_DIR, exist_ok=True)
            filename = time.strftime("%Y%m%d_%H%M%S") + "_%03d.jpg" % int((time.time() * 1000) % 1000); output = os.path.join(PHOTO_DIR, filename)
            try:
                with camera_lock:
                    global last_capture_at
                    wait = 1.0 - (time.time() - last_capture_at)
                    if wait > 0: time.sleep(wait)
                    out = err = b""
                    for attempt in range(2):
                        r = subprocess.Popen([CAPTURE, VIDEO, output], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                        try:
                            out, err = r.communicate(timeout=12)
                        except subprocess.TimeoutExpired:
                            r.kill(); out, err = r.communicate()
                        if r.returncode == 0: break
                        if attempt == 0: time.sleep(0.8)
                    last_capture_at = time.time()
                    if r.returncode:
                        raise RuntimeError("摄像头采集超时或无视频帧，请重新插拔摄像头")
                if r.returncode:
                    detail = err.decode("utf-8", "replace") or out.decode("utf-8", "replace")
                    raise RuntimeError(detail or "capture failed (exit %d)" % r.returncode)
                with state_lock: state["last_photo"] = filename
                json_response(self, {"ok": True, "file": filename}); return
            except Exception as exc:
                json_response(self, {"ok": False, "error": str(exc)}, 503); return
        if path in ("/api/ptz", "/api/ultrasonic"):
            try:
                if path == "/api/ptz":
                    pan = servo_angle(body.get("pan"), "水平")
                    tilt = servo_angle(body.get("tilt"), "垂直")
                    with servo_lock:
                        servo_mmio_write(0x00, pan)
                        servo_mmio_write(0x04, tilt)
                    servo_status_update(camera_pan=pan, camera_tilt=tilt)
                    json_response(self, {"ok": True, "message": "云台角度已写入 FPGA"}); return

                enable = body.get("enable")
                sweep = body.get("sweep", False)
                if not isinstance(enable, bool) or not isinstance(sweep, bool):
                    raise ValueError("enable 和 sweep 必须为布尔值")
                angle = servo_angle(body.get("angle", 90), "超声波舵机")
                with servo_lock:
                    servo_mmio_write(0x08, angle)
                    servo_mmio_write(0x0c, (1 if enable else 0) | (2 if sweep and enable else 0))
                servo_status_update(ultrasonic_angle=angle,
                                    ultrasonic_enabled=enable,
                                    ultrasonic_sweep=(sweep and enable))
                json_response(self, {"ok": True, "message": "超声波舵机命令已写入 FPGA"}); return
            except ValueError as exc:
                json_response(self, {"ok": False, "error": str(exc)}, 400); return
            except Exception as exc:
                json_response(self, {"ok": False, "error": str(exc)}, 503); return
        json_response(self, {"ok": False, "error": "未知接口"}, 404)


class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True


def main():
    os.makedirs(PHOTO_DIR, exist_ok=True)
    threading.Thread(target=gps_worker, daemon=True).start()
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print("boat web server listening on %s:%d" % (HOST, PORT), flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
