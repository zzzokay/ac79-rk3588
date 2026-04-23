# 📌 AC79 → RK3588 空间占用检测系统（UDP + CTP + RKNN）

## 🚀 项目简介
本项目基于 **杰理 AC79 摄像头开发板 + RK3588**，构建一套面向低清晰度视频流的空间占用检测系统。

系统实现：
- UDP 传输 JPEG 视频流
- CTP 协议控制摄像头
- RK3588 本地 RKNN 推理
- 人体检测 + 区域分析（ROI）+ 驻留统计（规划中）

---

## 🧠 系统架构

AC79 →（UDP JPEG）→ RK3588 →（RKNN 推理）→ 结果显示/分析

---

## ⚙️ 当前实现功能

- ✅ CTP 控制链路（open/close）
- ✅ UDP JPEG 视频流接收
- ✅ 实时图像解码与显示
- ✅ 帧保存（调试用）
- ✅ RKNN 模型推理入口（已打通）

---

# 🤖 模型推理模块（重点更新）

## 📌 推理流程

当前推理流程如下：

```
UDP 接收线程
    ↓
JPEG 解码（OpenCV）
    ↓
图像预处理（resize / BGR → RGB / normalize）
    ↓
RKNN 推理（YOLOv8n）
    ↓
后处理（NMS + 置信度筛选）
    ↓
绘制 bbox（仅 person）
    ↓
实时显示
```

---

## 📦 模型要求

推荐使用：

- 模型：YOLOv8n
- 框架：RKNN Toolkit2
- 精度：INT8（推荐）
- 输入尺寸：640x640

### 目录结构示例

```
models/
    person.rknn
    labels.txt
```

---

## ⚙️ 环境变量配置（.env）

```
MODEL_PATH=./models/person.rknn
LABELS_PATH=./models/labels.txt

OBJ_THRESH=0.25
NMS_THRESH=0.45

BGR_INPUT=1
SINGLE_CORE=1
```

---

## ▶️ 推理启动方式

```
./start_infer_all.sh
```

或手动运行：

```
python jieli_rknn_udp_infer.py
```

---

## 🧪 推理验证标准

运行后应满足：

- 能稳定接收视频流
- 实时画面无明显卡顿
- 能正确检测到“人”
- bbox 跟随目标移动
- 误检率可接受

---

## ⚠️ 常见问题

### 1️⃣ 模型加载失败

检查：
- MODEL_PATH 是否正确
- rknn 是否与 RK3588 架构匹配

---

### 2️⃣ 推理速度慢

优化建议：
- 使用 INT8 量化模型
- 开启 NPU 单核/多核切换
- 降低输入分辨率

---

### 3️⃣ 检测不到人

排查：
- 阈值过高（OBJ_THRESH）
- 输入图像尺寸不匹配
- 模型未正确转换

---

## 🚧 下一阶段开发

### 第3阶段：ROI 区域判断
- 判断目标所在区域（desk / door / room）

### 第4阶段：目标跟踪（ByteTrack）
- 分配 track_id
- 计算驻留时间

### 第5阶段：事件触发
- 超时报警
- 截图保存
- 音频提醒

---

## 📅 更新时间
2026-04-23 04:24:45
