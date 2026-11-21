#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// ONNX Runtime 的 C++ API 薄封装：只做「加载 + 一次前向」，避免在 Swift 里碰 C++。
@interface ONNXRunner : NSObject

- (nullable instancetype)initWithModelPath:(NSString *)path
                                   threads:(NSInteger)threads
                                     error:(NSError **)error;

@property (nonatomic, readonly, copy) NSString *inputName;
@property (nonatomic, readonly, copy) NSString *outputName;

/// 输入 float32 连续内存（NCHW），返回 @{ @"data": NSData(float32), @"shape": [NSNumber] }
- (nullable NSDictionary<NSString *, id> *)runWithFloatInput:(NSData *)input
                                                       shape:(NSArray<NSNumber *> *)shape
                                                       error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
