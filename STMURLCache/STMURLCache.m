//  Created by daiming on 2016/11/11. 

#import "STMURLCache.h"
#import <CommonCrypto/CommonDigest.h>

@interface STMURLCache()<UIWebViewDelegate>

@property (nonatomic, strong) STMURLCacheMk *mk;
@property (nonatomic, strong) UIWebView *wbView; //用于预加载的webview
@property (nonatomic, strong) NSMutableArray *preLoadWebUrls; //预加载的webview的url列表

@end

@implementation STMURLCache
#pragma mark - Interface
+ (STMURLCache *)create:(void (^)(STMURLCacheMk *))mk {
    STMURLCache *c = [[self alloc] initWithMemoryCapacity:0 diskCapacity:0 diskPath:nil];
    STMURLCacheMk *cMk = [[STMURLCacheMk alloc] init];
    cMk.isDownloadMode(YES);
    mk(cMk);
    c.mk = cMk;
    c = [c build];
    [NSURLCache setSharedURLCache:c];
    return c;
}

- (STMURLCache *)build {
    if (!self.mk.cModel.path) {
        self.mk.cModel.path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    }
    self.mk.cModel.isSavedOnDisk = YES;
    return self;
}

- (STMURLCache *)update:(void (^)(STMURLCacheMk *))mk {
    mk(self.mk);
    return self;
}

- (void)stop {
    NSURLCache *c = [[NSURLCache alloc] initWithMemoryCapacity:0 diskCapacity:0 diskPath:nil];
    [NSURLCache setSharedURLCache:c];
    [self.mk.cModel checkCapacity];
}

#pragma mark - Interface PreLoad by Webview
- (STMURLCache *)preLoadByWebViewWithUrls:(NSArray *)urls {
    if (!(urls.count > 0)) {
        return self;
    }
    self.wbView = [[UIWebView alloc] init];
    self.wbView.delegate = self;
    self.preLoadWebUrls = [NSMutableArray arrayWithArray:urls];
    [self requestWebWithFirstPreUrl];
    return self;
}
//web view delegate
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if (self.preLoadWebUrls.count > 0) {
        [self.preLoadWebUrls removeObjectAtIndex:0];
        [self requestWebWithFirstPreUrl];
    } else {
        self.wbView = nil;
    }
}
- (void)requestWebWithFirstPreUrl {
    NSURLRequest *re = [NSURLRequest requestWithURL:[NSURL URLWithString:self.preLoadWebUrls.firstObject]];
    [self.wbView loadRequest:re];
}

#pragma mark - Interface Preload by Request
- (STMURLCache *)preLoadByRequestWithUrls:(NSArray *)urls {
    NSUInteger i = 1;
    for (NSString *urlString in urls) {
        NSMutableURLRequest *re = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        re.HTTPMethod = @"GET";
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:re completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        }];
        [task resume];
        i++;
    }
    
    return self;
}


#pragma mark - NSURLCache Method
- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request {
    STMURLCacheModel *cModel = self.mk.cModel;
    //对于模式的过滤
    if (!cModel.isDownloadMode) {
        return nil;
    }
    //对于域名白名单的过滤
    if (self.mk.cModel.whiteListsHost.count > 0) {
        id isExist = [self.mk.cModel.whiteListsHost objectForKey:[self hostFromRequest:request]];
        if (!isExist) {
            return nil;
        }
    }
    //只允许GET方法通过
    if ([request.HTTPMethod compare:@"GET"] != NSOrderedSame) {
        return nil;
    }
    //User-Agent来过滤
    if (self.mk.cModel.whiteUserAgent.length > 0) {
        NSString *uAgent = [request.allHTTPHeaderFields objectForKey:@"User-Agent"];
        if (uAgent) {
            if (![uAgent hasSuffix:self.mk.cModel.whiteUserAgent]) {
                return nil;
            }
        }
    }
    //开始缓存
    NSCachedURLResponse *cachedResponse =  [cModel localCacheResponeWithRequest:request];
    if (cachedResponse) {
        [self storeCachedResponse:cachedResponse forRequest:request];
        return cachedResponse;
    }
    return nil;
}

#pragma mark - Cache Capacity

- (void)removeCachedResponseForRequest:(NSURLRequest *)request {
    [super removeCachedResponseForRequest:request];
    [self.mk.cModel removeCacheFileWithRequest:request];
}
- (void)removeAllCachedResponses {
    [super removeAllCachedResponses];
}

#pragma mark - Helper
- (NSString *)hostFromRequest:(NSURLRequest *)request {
    return [NSString stringWithFormat:@"%@",request.URL.host];
}

#pragma mark - Life
- (void)dealloc {
    NSURLCache *c = [[NSURLCache alloc] initWithMemoryCapacity:0 diskCapacity:0 diskPath:nil];
    [NSURLCache setSharedURLCache:c];
}

@end
