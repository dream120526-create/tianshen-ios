把模型放这里
==============

文件名固定，App 按档位找：
  yolov8n.onnx  ->  低配
  yolov8s.onnx  ->  中配
  yolov8m.onnx  ->  高配

· 仓里已内置 yolov8n.onnx（从安卓版提取，416 输入，可直接用）
· 中/高配用 Tools/fetch_models.py 导出，或者：
      yolo export model=yolov8s.pt format=onnx imgsz=416 opset=12
      yolo export model=yolov8m.pt format=onnx imgsz=416 opset=12
· 不想改工程也行：把 .onnx 塞进手机「文件 → 我的 iPhone → 天神辅助 → Models」，
  App 优先读那里。
