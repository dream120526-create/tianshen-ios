import Foundation

/// COCO 80 类（与模型输出顺序一致）
enum Catalog {
    static let coco80: [String] = [
        "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat",
        "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat",
        "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack",
        "umbrella", "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball",
        "kite", "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket",
        "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple",
        "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair",
        "couch", "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse",
        "remote", "keyboard", "cell phone", "microwave", "oven", "toaster", "sink",
        "refrigerator", "book", "clock", "vase", "scissors", "teddy bear", "hair drier",
        "toothbrush"
    ]

    /// 参与识别的目标类别（人 + 常见动物 + 常见车辆）
    static let targetClasses: [String] = [
        "person",
        "cat", "dog", "bird", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe",
        "car", "truck", "bus", "bicycle", "motorcycle", "boat", "airplane", "train"
    ]

    static let labels: [String: String] = [
        "person": "人", "cat": "猫", "dog": "狗", "bird": "鸟", "horse": "马", "sheep": "羊",
        "cow": "牛", "elephant": "大象", "bear": "熊", "zebra": "斑马", "giraffe": "长颈鹿",
        "car": "汽车", "truck": "卡车", "bus": "公交车", "bicycle": "自行车",
        "motorcycle": "摩托车", "boat": "船", "airplane": "飞机", "train": "火车"
    ]

    struct FilterGroup: Identifiable {
        var id: String { label }
        let label: String
        let classes: [String]
    }

    static let filterGroups: [FilterGroup] = [
        FilterGroup(label: "人", classes: ["person"]),
        FilterGroup(label: "动物", classes: [
            "cat", "dog", "bird", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe"
        ]),
        FilterGroup(label: "车辆", classes: [
            "car", "truck", "bus", "bicycle", "motorcycle", "boat", "airplane", "train"
        ])
    ]

    static func label(for cls: String) -> String {
        labels[cls] ?? cls
    }
}
