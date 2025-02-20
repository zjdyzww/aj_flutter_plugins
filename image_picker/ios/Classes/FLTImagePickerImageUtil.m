// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FLTImagePickerImageUtil.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "UIImage+AJScale.h"

@interface GIFInfo ()

@property(strong, nonatomic, readwrite) NSArray<UIImage *> *images;
@property(assign, nonatomic, readwrite) NSTimeInterval interval;

@end

@implementation GIFInfo

- (instancetype)initWithImages:(NSArray<UIImage *> *)images interval:(NSTimeInterval)interval;
{
  self = [super init];
  if (self) {
    self.images = images;
    self.interval = interval;
  }
  return self;
}

@end

@implementation FLTImagePickerImageUtil : NSObject

+ (UIImage *)scaledImage:(UIImage *)image
                maxWidth:(NSNumber *)maxWidth
               maxHeight:(NSNumber *)maxHeight {
  double originalWidth = image.size.width;
  double originalHeight = image.size.height;

  bool hasMaxWidth = maxWidth != (id)[NSNull null];
  bool hasMaxHeight = maxHeight != (id)[NSNull null];

  double width = hasMaxWidth ? MIN([maxWidth doubleValue], originalWidth) : originalWidth;
  double height = hasMaxHeight ? MIN([maxHeight doubleValue], originalHeight) : originalHeight;

  bool shouldDownscaleWidth = hasMaxWidth && [maxWidth doubleValue] < originalWidth;
  bool shouldDownscaleHeight = hasMaxHeight && [maxHeight doubleValue] < originalHeight;
  bool shouldDownscale = shouldDownscaleWidth || shouldDownscaleHeight;

  if (shouldDownscale) {
    double downscaledWidth = floor((height / originalHeight) * originalWidth);
    double downscaledHeight = floor((width / originalWidth) * originalHeight);

    if (width < height) {
      if (!hasMaxWidth) {
        width = downscaledWidth;
      } else {
        height = downscaledHeight;
      }
    } else if (height < width) {
      if (!hasMaxHeight) {
        height = downscaledHeight;
      } else {
        width = downscaledWidth;
      }
    } else {
      if (originalWidth < originalHeight) {
        width = downscaledWidth;
      } else if (originalHeight < originalWidth) {
        height = downscaledHeight;
      }
    }
  }

  UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), NO, 1.0);
  [image drawInRect:CGRectMake(0, 0, width, height)];

  UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  return scaledImage;
}

+ (GIFInfo *)scaledGIFImage:(NSData *)data
                   maxWidth:(NSNumber *)maxWidth
                  maxHeight:(NSNumber *)maxHeight {
  NSMutableDictionary<NSString *, id> *options = [NSMutableDictionary dictionary];
  options[(NSString *)kCGImageSourceShouldCache] = @(YES);
  options[(NSString *)kCGImageSourceTypeIdentifierHint] = (NSString *)kUTTypeGIF;

  CGImageSourceRef imageSource =
      CGImageSourceCreateWithData((CFDataRef)data, (CFDictionaryRef)options);

  size_t numberOfFrames = CGImageSourceGetCount(imageSource);
  NSMutableArray<UIImage *> *images = [NSMutableArray arrayWithCapacity:numberOfFrames];

  NSTimeInterval interval = 0.0;
  for (size_t index = 0; index < numberOfFrames; index++) {
    CGImageRef imageRef =
        CGImageSourceCreateImageAtIndex(imageSource, index, (CFDictionaryRef)options);

    NSDictionary *properties = (NSDictionary *)CFBridgingRelease(
        CGImageSourceCopyPropertiesAtIndex(imageSource, index, NULL));
    NSDictionary *gifProperties = properties[(NSString *)kCGImagePropertyGIFDictionary];

    NSNumber *delay = gifProperties[(NSString *)kCGImagePropertyGIFUnclampedDelayTime];
    if (!delay) {
      delay = gifProperties[(NSString *)kCGImagePropertyGIFDelayTime];
    }

    if (interval == 0.0) {
      interval = [delay doubleValue];
    }

    UIImage *image = [UIImage imageWithCGImage:imageRef scale:1.0 orientation:UIImageOrientationUp];
    image = [self scaledImage:image maxWidth:maxWidth maxHeight:maxHeight];

    [images addObject:image];

    CGImageRelease(imageRef);
  }

  CFRelease(imageSource);

  GIFInfo *info = [[GIFInfo alloc] initWithImages:images interval:interval];

  return info;
}

+ (UIImage *)compressImage:(UIImage *)image
         maxDataSizeKBytes:(double)maxSize
            needChangeSize: (BOOL)needChange {
    
    if (maxSize <= 0) {
        return  image;
    }
    
    double originalWidth = image.size.width;
    double originalHeight = image.size.height;
    double maxWidth = 1024;
    //调整图片尺寸
    if (needChange && originalWidth > maxWidth){
        image = [image scaleWithMinWidth:maxWidth minHeight:maxWidth*(originalHeight/originalWidth)];
    }
    
    CGFloat targetMaxSize = maxSize;
    NSData * data = UIImageJPEGRepresentation(image, 1.0);
    NSInteger px = data.length/(targetMaxSize*1024); //换算原图大小 与 目标大小的备差
    CGFloat minQ = 0.9f;
    UIImage *targetImage = image;
    //原图大小与目标大小差距过大先进行一次压缩处理
    if (px > 5) {
        minQ = 1.0/px;
        data = UIImageJPEGRepresentation(image, minQ);
        targetImage = [UIImage imageWithData:data];
        return targetImage;
    }
    
    CGFloat maxQuality = 0.9f;
    data = UIImageJPEGRepresentation(targetImage, maxQuality);
    CGFloat dataKBytes = data.length/1024.0;
    CGFloat lastData = dataKBytes;
    //每次质量递减 5%
    while (dataKBytes > targetMaxSize && maxQuality > 0.05f) {
      maxQuality = maxQuality - 0.05f;
      data = UIImageJPEGRepresentation(targetImage, maxQuality);
      dataKBytes = data.length / 1024.0;
      if (lastData == dataKBytes) {
        break;
      }else{
        lastData = dataKBytes;
      }
    }
    return [UIImage imageWithData:data];
}



@end
