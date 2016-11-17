# iOS预加载Web页面方案
可以先下载Demo看看效果，Github地址：< [GitHub - ming1016/STMURLCache: iOS预加载Web页面方案](https://github.com/ming1016/STMURLCache) >
可以预加载多个网址，然后在离线状态去显示那几个网址，看看是不是都完全缓存下来了。

## 使用方法
在需要开启预加载的地方创建
```objective-c
self.sCache = [STMURLCache create:^(STMURLCacheMk *mk) {
    mk.whiteListsHost(whiteLists).whiteUserAgent(@"starming");
}];
```

这里是所有可设置项目，默认设置可以查看 model 的 get 方法
```objective-c
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
```

也可以随时更新这些设置项
```objective-c
[self.sCache update:^(STMURLCacheMk *mk) {
    mk.isDownloadMode(YES);
}];
```

预加载名单可以按照整个 web 页面请求进行预加载
```objective-c
[self.sCache preLoadByWebViewWithUrls:@[@"http://www.v2ex.com",@"http://www.github.com"];
```
如果需要按照单个资源列表进行预加载可以使用 *preLoadByRequestWithUrls* 这个方法。

## 白名单设置
对于只希望缓存特定域名或者地址的可以通过白名单进行设置，可以在创建时进行设置或者更新时设置。
```objective-c
NSString *whiteListStr = @"www.starming.com|www.github.com|www.v2ex.com|www.baidu.com";
NSMutableArray *whiteLists = [NSMutableArray arrayWithArray:[whiteListStr componentsSeparatedByString:@"|"]];
self.sCache = [STMURLCache create:^(STMURLCacheMk *mk) {
    mk.whiteListsHost(whiteLists).whiteUserAgent(@"starming");
}];
```
这里的 *whiteUserAgent* 的设置会设置 webview 的 UserAgent，这样能够让webview以外的网络请求被过滤掉。

## 基本加载缓存实现原理
创建 *STMURLCache* 后设置 *NSURLCache* 的 *URLCache* ，在 *cachedResponseForRequest* 方法中获取 *NSURLRequest* 判断白名单，检验是否有与之对应的 Cache ，有就使用本地数据返回 *NSCachedURLResponse* ，没有就通过网络获取数据数据缓存。 *STMURLCache* 对象释放时将 *NSURLCache* 设置为不缓存，表示这次预加载完成不需要再缓存。当缓存空间超出设置大小会将其清空。

## 白名单实现原理
创建域名列表设置项 *whiteListsHost* 和 *userAgent* 设置项，在创建和更新时对其进行设置。在网络请求开始通过设置项进行过滤。具体实现如下
```objective-c
//对于域名白名单的过滤
if (self.mk.cModel.whiteListsHost.count > 0) {
    id isExist = [self.mk.cModel.whiteListsHost objectForKey:[self hostFromRequest:request]];
    if (!isExist) {
        return nil;
    }
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
```

## 具体缓存实现
没有缓存的 request 会对其进行请求将获取数据按照hash地址存两份于本地，一份是数据，一份记录时间和类型，时间记录可以用于判断失效时间。对于判断是否有缓存可以根据请求地址对应的文件进行判断。具体实现如下：
```objective-c
- (NSCachedURLResponse *)localCacheResponeWithRequest:(NSURLRequest *)request {
    __block NSCachedURLResponse *cachedResponse = nil;
    NSString *filePath = [self filePathFromRequest:request isInfo:NO];
    NSString *otherInfoPath = [self filePathFromRequest:request isInfo:YES];
    NSDate *date = [NSDate date];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:filePath]) {
        //有缓存文件的情况
        BOOL expire = false;
        NSDictionary *otherInfo = [NSDictionary dictionaryWithContentsOfFile:otherInfoPath];
        if (self.cacheTime > 0) {
            NSInteger createTime = [[otherInfo objectForKey:@"time"] integerValue];
            if (createTime + self.cacheTime < [date timeIntervalSince1970]) {
                expire = true;
            }
        }
        if (expire == false) {
            //从缓存里读取数据
            NSData *data = [NSData dataWithContentsOfFile:filePath];
            NSURLResponse *response = [[NSURLResponse alloc] initWithURL:request.URL MIMEType:[otherInfo objectForKey:@"MIMEType"] expectedContentLength:data.length textEncodingName:[otherInfo objectForKey:@"textEncodingName"]];
            NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:data];
            return cachedResponse;
        } else {
            //cache失效了
            [fm removeItemAtPath:filePath error:nil];      //清除缓存data
            [fm removeItemAtPath:otherInfoPath error:nil]; //清除缓存其它信息
            return nil;
        }
    } else {
        //从网络读取
        self.isSavedOnDisk = NO;
        id isExist = [self.responseDic objectForKey:request.URL.absoluteString];
        if (isExist == nil) {
            [self.responseDic setValue:[NSNumber numberWithBool:TRUE] forKey:request.URL.absoluteString];
            NSURLSession *session = [NSURLSession sharedSession];
            NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                if (error) {
                    cachedResponse = nil;
                } else {
                    NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%f",[date timeIntervalSince1970]],@"time",response.MIMEType,@"MIMEType",response.textEncodingName,@"textEncodingName", nil];
                    BOOL resultO = [dic writeToFile:otherInfoPath atomically:YES];
                    BOOL result = [data writeToFile:filePath atomically:YES];
                    if (resultO == NO || result == NO) {
                    } else {
                    }
                    cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:data];
                }
            }];
            [task resume];
            return cachedResponse;
        }
        return nil;
    }
}
```

完整代码：< [GitHub - ming1016/STMURLCache: iOS预加载Web页面方案](https://github.com/ming1016/STMURLCache) >
