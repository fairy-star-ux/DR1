import cv2
import os
import time
import signal
import base64
from ultralytics import YOLO
import psutil  # 用于降低自身CPU优先级

# ====================== 全局配置参数 ======================
# 文件路径
ANGLE_FILE       = "angle.txt"
RESULT_FILE      = "result.txt"

# 摄像头配置
CAMERA_WIDTH     = 640
CAMERA_HEIGHT    = 480
YOLO_MODEL_PATH  = "/home/user/yolov8n.pt"

# 识别配置
DETECT_CONFIDENCE     = 0.3
DETECT_CLASSES        = [0]      # 只识别人
BASE64_JPEG_QUALITY   = 80

# 时间配置
FILE_CHECK_INTERVAL   = 0.5     # 检查文件更新的间隔（秒，缩短到0.5秒）
CAPTURE_DELAY         = 0.3       # 舵机转到位后等待抓拍的时间

# ====================== 图片转Base64工具函数 ======================
def image_to_base64(image):
    """将OpenCV图片对象转换为UTF-8编码的Base64字符串"""
    ret, buffer = cv2.imencode('.jpg', image, [int(cv2.IMWRITE_JPEG_QUALITY), BASE64_JPEG_QUALITY])
    if not ret:
        print("[vision] 图片编码失败")
        return ""
    return base64.b64encode(buffer).decode('utf-8')

# ====================== 摄像头人像识别模块 ======================
class CameraDetector:
    def __init__(self):
        print("[vision] 正在加载YOLO人像识别模型...")
        self.model = YOLO(YOLO_MODEL_PATH, task="detect")
        print("[vision] YOLO模型加载成功")

        print("[vision] 正在查找可用摄像头...")
        self.cap = None
        for i in range(6):
            cap = cv2.VideoCapture(f"/dev/video{i}", cv2.CAP_V4L2)
            cap.set(cv2.CAP_PROP_FRAME_WIDTH, CAMERA_WIDTH)
            cap.set(cv2.CAP_PROP_FRAME_HEIGHT, CAMERA_HEIGHT)
            cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*'MJPG'))
            if cap.isOpened():
                ret, _ = cap.read()
                if ret:
                    self.cap = cap
                    print(f"[vision] 找到可用摄像头：/dev/video{i}")
                    break
            cap.release()

        if not self.cap:
            print("[vision] 未找到可用摄像头，请检查设备连接")
            exit(1)

    def capture_and_detect(self):
        """
        抓拍并执行人像识别
        返回: (是否有人, Base64字符串)
        """
        print("[vision] 正在抓拍并识别...")
        time.sleep(CAPTURE_DELAY)

        # 抓拍3帧，取最后一帧（消除摄像头延迟）
        frame = None
        for _ in range(3):
            ret, frame = self.cap.read()
            if not ret:
                time.sleep(0.1)

        if frame is None or not ret:
            print("[vision] 抓拍失败")
            return False, ""

        # 执行人像识别（CPU密集型！）
        results = self.model(frame, classes=DETECT_CLASSES,
                             conf=DETECT_CONFIDENCE, verbose=False)
        person_count = len(results[0].boxes)
        has_person = person_count > 0

        # 1. 保存原始抓拍图片
        cv2.imwrite("capture_raw.jpg", frame)
        print("[vision] 原始图片已保存：capture_raw.jpg")

        # 2. 保存带检测框的结果图
        result_frame = results[0].plot()
        cv2.imwrite("capture_result.jpg", result_frame)
        print("[vision] 带框结果图已保存：capture_result.jpg")

        # 3. 生成Base64字符串
        base64_str = image_to_base64(frame)
        if base64_str:
            with open("capture_base64.txt", "w", encoding="utf-8") as f:
                f.write(base64_str)
            print(f"[vision] Base64字符串已保存：capture_base64.txt ({len(base64_str)}字节)")

        print(f"[vision] 识别完成，检测到 {person_count} 个人 → {'是' if has_person else '否'}")
        return has_person, base64_str

    def cleanup(self):
        """释放摄像头资源"""
        if self.cap:
            self.cap.release()
        print("[vision] 摄像头资源已释放")

# ====================== 文件操作模块 ======================
class FileManager:
    def __init__(self, angle_file, result_file):
        self.angle_file = angle_file
        self.result_file = result_file
        self.last_modified_time = 0

        # 初始化文件
        if not os.path.exists(self.angle_file):
            with open(self.angle_file, "w") as f:
                f.write("0")
            print(f"[vision] 创建角度文件：{self.angle_file}")

        if not os.path.exists(self.result_file):
            with open(self.result_file, "w") as f:
                f.write("waiting")
            print(f"[vision] 创建结果文件：{self.result_file}")

        # 记录初始mtime
        self.last_modified_time = os.path.getmtime(self.angle_file)

    def is_file_updated(self):
        """检查角度文件是否有更新"""
        try:
            current_modified = os.path.getmtime(self.angle_file)
            if current_modified > self.last_modified_time:
                self.last_modified_time = current_modified
                return True
        except FileNotFoundError:
            pass
        return False

    def read_angle(self):
        """读取角度值（仅用于日志记录）"""
        try:
            with open(self.angle_file, "r") as f:
                content = f.read().strip()
            angle = int(float(content))
            if -90 <= angle <= 90:
                print(f"[vision] C程序请求的视觉角度：{angle}°")
                return angle
            else:
                print(f"[vision] 角度超出范围，忽略")
                return None
        except Exception as e:
            print(f"[vision] 读取角度文件失败：{e}")
            return None

    def write_processing(self):
        """写入processing状态，通知C程序视觉已开始工作"""
        try:
            with open(self.result_file, "w", encoding="utf-8") as f:
                f.write("processing")
            print("[vision] 写入状态：processing（视觉工作中）")
        except Exception as e:
            print(f"[vision] 写入processing状态失败：{e}")

    def write_result(self, result):
        """写入识别结果（yes/no）"""
        try:
            text = "yes" if result else "no"
            with open(self.result_file, "w", encoding="utf-8") as f:
                f.write(text)
            print(f"[vision] 写入识别结果：{text}")
        except Exception as e:
            print(f"[vision] 写入结果文件失败：{e}")

# ====================== 主程序 ======================
if __name__ == "__main__":
    detector = None
    file_manager = None

    def signal_handler(signum, frame):
        print("\n[vision] 收到中断信号，正在释放资源...")
        if detector:
            detector.cleanup()
        print("[vision] 程序正常退出")
        exit(0)

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    try:
        # 降低自身CPU优先级，避免抢占C程序的实时线程
        try:
            p = psutil.Process(os.getpid())
            p.nice(19)  # 最低nice值，让出CPU给C程序
            print("[vision] CPU优先级已降至最低 (nice=19)")
        except Exception as e:
            print(f"[vision] 警告：无法降低CPU优先级: {e}")

        # 初始化
        detector = CameraDetector()
        file_manager = FileManager(ANGLE_FILE, RESULT_FILE)

        print("\n" + "="*50)
        print("[vision] ✅ 纯视觉服务已启动")
        print("[vision] 职责：拍照 + YOLO推理 + 保存结果")
        print("[vision] 不再控制舵机（由C程序统一管理）")
        print("="*50 + "\n")

        # 主循环
        while True:
            if file_manager.is_file_updated():
                angle = file_manager.read_angle()
                if angle is not None:
                    # Step 1: 立即写processing状态，通知C程序视觉已开始
                    file_manager.write_processing()

                    # Step 2: C程序已经把视觉舵机转到位了，直接拍照+YOLO
                    has_person, b64_str = detector.capture_and_detect()

                    # Step 3: 写入最终识别结果
                    file_manager.write_result(has_person)
                    print("-" * 50)

            time.sleep(FILE_CHECK_INTERVAL)

    except Exception as e:
        print(f"\n[vision] 程序发生错误：{e}")
    finally:
        if detector:
            detector.cleanup()
        print("[vision] 所有资源已释放")
