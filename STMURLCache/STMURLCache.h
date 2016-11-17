//  Created by daiming on 2016/11/11.
/*
 功能：缓存网络请求
 */

#import <Foundation/Foundation.h>
#import "STMURLCacheMk.h"

@interface STMURLCache : NSURLCache

+ (STMURLCache *)create:(void(^)(STMURLCacheMk *mk))mk;  //初始化并开启缓存
- (STMURLCache *)update:(void (^)(STMURLCacheMk *mk))mk;

- (STMURLCache *)preLoadByWebViewWithUrls:(NSArray *)urls; //使用WebView进行预加载缓存
- (STMURLCache *)preLoadByRequestWithUrls:(NSArray *)urls; //使用
- (void)stop; //关闭缓存

@end
