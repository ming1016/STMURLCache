//  Created by daiming on 2016/11/11.

#import <UIKit/UIKit.h>
#import "STMURLCacheModel.h"

@interface STMURLCacheMk : NSObject

@property (nonatomic, strong) STMURLCacheModel *cModel;

- (STMURLCacheMk *(^)(NSUInteger)) memoryCapacity;   //内存容量
- (STMURLCacheMk *(^)(NSUInteger)) diskCapacity;     //本地存储容量
- (STMURLCacheMk *(^)(NSString *)) path;             //路径
- (STMURLCacheMk *(^)(NSUInteger)) cacheTime;        //缓存时间
- (STMURLCacheMk *(^)(NSString *)) subDirectory;     //子目录
- (STMURLCacheMk *(^)(BOOL)) isDownloadMode;         //是否启动下载模式
- (STMURLCacheMk *(^)(NSArray *)) whiteListsHost;    //域名白名单
- (STMURLCacheMk *(^)(NSString *)) whiteUserAgent;   //WebView的user-agent白名单

- (STMURLCacheMk *(^)(NSString *)) addHostWhiteList;        //添加一个域名白名单
- (STMURLCacheMk *(^)(NSString *)) addRequestUrlWhiteList;  //添加请求白名单


@end
