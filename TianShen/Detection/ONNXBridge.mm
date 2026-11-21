#import "ONNXBridge.h"

#include <onnxruntime/onnxruntime_cxx_api.h>

#include <cstring>
#include <memory>
#include <string>
#include <vector>

static NSString *const ONNXBridgeDomain = @"com.local.tianshen.onnx";

static NSError *ONNXError(const std::exception &e) {
    return [NSError errorWithDomain:ONNXBridgeDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey:
                                          [NSString stringWithUTF8String:e.what()] ?: @"onnxruntime error"}];
}

namespace {

// float32 <-> float16（IEEE 754 binary16），不依赖任何头文件里的辅助类型
inline uint16_t half_from_float(float value) {
    uint32_t bits;
    std::memcpy(&bits, &value, sizeof(bits));

    uint32_t sign = (bits >> 16) & 0x8000u;
    int32_t exponent = (int32_t)((bits >> 23) & 0xff) - 127 + 15;
    uint32_t mantissa = bits & 0x7fffffu;

    if (exponent <= 0) {
        if (exponent < -10) { return (uint16_t)sign; }
        mantissa |= 0x800000u;
        uint32_t shift = (uint32_t)(14 - exponent);
        uint32_t rounded = mantissa >> shift;
        if ((mantissa >> (shift - 1)) & 1u) { rounded += 1; }
        return (uint16_t)(sign | rounded);
    }
    if (exponent >= 31) {
        return (uint16_t)(sign | 0x7c00u | (mantissa ? 0x200u : 0u));
    }
    uint32_t rounded = mantissa >> 13;
    if ((mantissa >> 12) & 1u) { rounded += 1; }
    return (uint16_t)(sign | ((uint32_t)exponent << 10) | rounded);
}

inline float float_from_half(uint16_t half) {
    uint32_t sign = ((uint32_t)half & 0x8000u) << 16;
    uint32_t exponent = ((uint32_t)half >> 10) & 0x1fu;
    uint32_t mantissa = (uint32_t)half & 0x3ffu;
    uint32_t bits;

    if (exponent == 0) {
        if (mantissa == 0) {
            bits = sign;
        } else {
            exponent = 1;
            while ((mantissa & 0x400u) == 0) {
                mantissa <<= 1;
                exponent -= 1;
            }
            mantissa &= 0x3ffu;
            bits = sign | ((exponent + 127 - 15) << 23) | (mantissa << 13);
        }
    } else if (exponent == 0x1fu) {
        bits = sign | 0x7f800000u | (mantissa << 13);
    } else {
        bits = sign | ((exponent + 127 - 15) << 23) | (mantissa << 13);
    }

    float result;
    std::memcpy(&result, &bits, sizeof(result));
    return result;
}

}  // namespace

@implementation ONNXRunner {
    std::unique_ptr<Ort::Env> _env;
    std::unique_ptr<Ort::Session> _session;
    std::string _inputName;
    std::string _outputName;
    BOOL _inputIsHalf;
}

- (instancetype)initWithModelPath:(NSString *)path
                          threads:(NSInteger)threads
                            error:(NSError **)error {
    self = [super init];
    if (!self) { return nil; }

    try {
        Ort::SessionOptions options;
        options.SetIntraOpNumThreads((int)MAX(1, threads));
        options.SetGraphOptimizationLevel(GraphOptimizationLevel::ORT_ENABLE_ALL);

        _env = std::make_unique<Ort::Env>(ORT_LOGGING_LEVEL_WARNING, "tianshen");
        _session = std::make_unique<Ort::Session>(*_env, path.UTF8String, options);

        Ort::AllocatorWithDefaultOptions allocator;
        _inputName = "images";
        _outputName = "output0";
        _inputIsHalf = NO;

        if (_session->GetInputCount() > 0) {
            auto name = _session->GetInputNameAllocated(0, allocator);
            if (name.get()) { _inputName = name.get(); }
            auto info = _session->GetInputTypeInfo(0).GetTensorTypeAndShapeInfo();
            _inputIsHalf = (info.GetElementType() == ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16);
        }
        if (_session->GetOutputCount() > 0) {
            auto name = _session->GetOutputNameAllocated(0, allocator);
            if (name.get()) { _outputName = name.get(); }
        }
    } catch (const std::exception &e) {
        if (error) { *error = ONNXError(e); }
        return nil;
    }
    return self;
}

- (NSString *)inputName {
    return [NSString stringWithUTF8String:_inputName.c_str()] ?: @"images";
}

- (NSString *)outputName {
    return [NSString stringWithUTF8String:_outputName.c_str()] ?: @"output0";
}

- (BOOL)inputIsHalf {
    return _inputIsHalf;
}

- (NSDictionary<NSString *, id> *)runWithFloatInput:(NSData *)input
                                              shape:(NSArray<NSNumber *> *)shape
                                               half:(BOOL)half
                                              error:(NSError **)error {
    if (!_session) {
        if (error) {
            *error = [NSError errorWithDomain:ONNXBridgeDomain code:2
                                     userInfo:@{NSLocalizedDescriptionKey: @"session 未加载"}];
        }
        return nil;
    }

    try {
        std::vector<int64_t> dims;
        dims.reserve(shape.count);
        for (NSNumber *n in shape) { dims.push_back((int64_t)n.longLongValue); }

        auto memoryInfo = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);

        std::vector<uint16_t> halfBuffer;
        Ort::Value tensor{nullptr};

        if (half) {
            size_t elementCount = input.length / sizeof(float);
            const float *src = reinterpret_cast<const float *>(input.bytes);
            halfBuffer.resize(elementCount);
            for (size_t i = 0; i < elementCount; ++i) {
                halfBuffer[i] = half_from_float(src[i]);
            }
            tensor = Ort::Value::CreateTensor(
                memoryInfo,
                halfBuffer.data(),
                elementCount,
                dims.data(),
                dims.size(),
                ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16);
        } else {
            size_t elementCount = input.length / sizeof(float);
            tensor = Ort::Value::CreateTensor<float>(
                memoryInfo,
                const_cast<float *>(reinterpret_cast<const float *>(input.bytes)),
                elementCount,
                dims.data(),
                dims.size());
        }

        const char *inputNames[] = {_inputName.c_str()};
        const char *outputNames[] = {_outputName.c_str()};

        auto outputs = _session->Run(Ort::RunOptions{nullptr},
                                     inputNames, &tensor, 1,
                                     outputNames, 1);
        if (outputs.empty()) {
            if (error) {
                *error = [NSError errorWithDomain:ONNXBridgeDomain code:3
                                         userInfo:@{NSLocalizedDescriptionKey: @"推理无输出"}];
            }
            return nil;
        }

        auto info = outputs[0].GetTensorTypeAndShapeInfo();
        auto outDims = info.GetShape();
        size_t outCount = info.GetElementCount();
        auto outType = info.GetElementType();

        NSMutableArray<NSNumber *> *shapeArray = [NSMutableArray arrayWithCapacity:outDims.size()];
        for (auto d : outDims) { [shapeArray addObject:@(d)]; }

        // 输出统一转成 float32 交给 Swift
        NSData *data = nil;
        if (outType == ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16) {
            const uint16_t *src = outputs[0].GetTensorData<uint16_t>();
            std::vector<float> converted(outCount);
            for (size_t i = 0; i < outCount; ++i) {
                converted[i] = float_from_half(src[i]);
            }
            data = [NSData dataWithBytes:converted.data() length:outCount * sizeof(float)];
        } else {
            void *raw = outputs[0].GetTensorMutableData<void>();
            data = [NSData dataWithBytes:raw length:outCount * sizeof(float)];
        }

        return @{@"data" : data, @"shape" : shapeArray};
    } catch (const std::exception &e) {
        if (error) { *error = ONNXError(e); }
        return nil;
    }
}

@end
