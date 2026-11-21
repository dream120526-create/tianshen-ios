#import "ONNXBridge.h"

#include <onnxruntime/onnxruntime_cxx_api.h>

#include <memory>
#include <string>
#include <vector>

static NSString *const ONNXBridgeDomain = @"com.local.tianshen.onnx";

static NSError *ONNXError(const std::exception &e) {
    return [NSError errorWithDomain:ONNXBridgeDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()] ?: @"onnxruntime error"}];
}

@implementation ONNXRunner {
    std::unique_ptr<Ort::Env> _env;
    std::unique_ptr<Ort::Session> _session;
    std::string _inputName;
    std::string _outputName;
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
        if (_session->GetInputCount() > 0) {
            auto name = _session->GetInputNameAllocated(0, allocator);
            _inputName = name.get();
        }
        if (_session->GetOutputCount() > 0) {
            auto name = _session->GetOutputNameAllocated(0, allocator);
            _outputName = name.get();
        }
        if (_inputName.empty()) { _inputName = "images"; }
        if (_outputName.empty()) { _outputName = "output0"; }
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

- (NSDictionary<NSString *, id> *)runWithFloatInput:(NSData *)input
                                              shape:(NSArray<NSNumber *> *)shape
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
        size_t elementCount = input.length / sizeof(float);

        Ort::Value tensor = Ort::Value::CreateTensor<float>(
            memoryInfo,
            const_cast<float *>(reinterpret_cast<const float *>(input.bytes)),
            elementCount,
            dims.data(),
            dims.size());

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

        NSMutableArray<NSNumber *> *shapeArray = [NSMutableArray arrayWithCapacity:outDims.size()];
        for (auto d : outDims) { [shapeArray addObject:@(d)]; }

        void *raw = outputs[0].GetTensorMutableData<void>();
        NSData *data = [NSData dataWithBytes:raw length:outCount * sizeof(float)];

        return @{@"data": data, @"shape": shapeArray};
    } catch (const std::exception &e) {
        if (error) { *error = ONNXError(e); }
        return nil;
    }
}

@end
