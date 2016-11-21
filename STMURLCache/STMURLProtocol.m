//
//  STMURLProtocol.m
//  Pods
//
//  Created by daiming on 2016/11/20.
//
//

#import "STMURLProtocol.h"
#import "STMURLCache.h"
#import <CommonCrypto/CommonDigest.h>

static NSString *STMURLProtocolHandled = @"STMURLProtocolHandled";

@interface STMURLProtocol()

@property (nonatomic, readwrite, strong) NSURLConnection *connection;
@property (nonatomic, readwrite, strong) NSMutableData *data;
@property (nonatomic, readwrite, strong) NSURLResponse *response;

@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, copy) NSString *otherInfoPath;

@end

@implementation STMURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    
    if ([NSURLProtocol propertyForKey:STMURLProtocolHandled inRequest:request]) {
        return NO;
    }
    NSString *scheme = [[request.URL scheme] lowercaseString];
    if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
        //
    } else {
        return NO;
    }
    
    return YES;
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}
+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (void)startLoading {
    self.filePath = [self filePathFromRequest:self.request isInfo:NO];
    self.otherInfoPath = [self filePathFromRequest:self.request isInfo:YES];
    NSDate *date = [NSDate date];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL expire = false;
    if ([fm fileExistsAtPath:self.filePath]) {
        //有缓存文件的情况
        NSDictionary *otherInfo = [NSDictionary dictionaryWithContentsOfFile:self.otherInfoPath];
        NSInteger createTime = [[otherInfo objectForKey:@"time"] integerValue];
        if (createTime + 24 * 60 * 60 < [date timeIntervalSince1970]) {
            expire = true;
        }
        if (expire == false) {
            //从缓存里读取数据
            NSData *data = [NSData dataWithContentsOfFile:self.filePath];
            NSURLResponse *response = [[NSURLResponse alloc] initWithURL:self.request.URL MIMEType:[otherInfo objectForKey:@"MIMEType"] expectedContentLength:data.length textEncodingName:[otherInfo objectForKey:@"textEncodingName"]];
            
            [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
            [self.client URLProtocol:self didLoadData:data];
            [self.client URLProtocolDidFinishLoading:self];
        } else {
            //cache失效了
            [fm removeItemAtPath:self.filePath error:nil];      //清除缓存data
            [fm removeItemAtPath:self.otherInfoPath error:nil]; //清除缓存其它信息
        }
    } else {
        expire = true;
    }
    
    if (expire) {
        NSMutableURLRequest *newRequest = [self.request mutableCopy];
        [NSURLProtocol setProperty:@YES forKey:STMURLProtocolHandled inRequest:newRequest];
        
        self.connection = [NSURLConnection connectionWithRequest:newRequest delegate:self];
    }
    
}

- (void)stopLoading {
    [self.connection cancel];
}

#pragma mark - NSURLConnection Delegate
- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    self.response = response;
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
    [self appendData:data];
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection {
    [self.client URLProtocolDidFinishLoading:self];
    
    //开始缓存
    NSDate *date = [NSDate date];
    NSDictionary *dic = [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%f",[date timeIntervalSince1970]],@"time",self.response.MIMEType,@"MIMEType",self.response.textEncodingName,@"textEncodingName", nil];
    [dic writeToFile:self.otherInfoPath atomically:YES];
    [self.data writeToFile:self.filePath atomically:YES];
    
    [self clear];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
    [self clear];
}

//
- (void)clear {
    [self setData:nil];
    [self setConnection:nil];
    [self setResponse:nil];
}
- (void)appendData:(NSData *)newData
{
    if ([self data] == nil) {
        [self setData:[newData mutableCopy]];
    }
    else {
        [[self data] appendData:newData];
    }
}

//
#pragma mark - Cache Helper
- (NSString *)filePathFromRequest:(NSURLRequest *)request isInfo:(BOOL)info {
    NSString *url = request.URL.absoluteString;
    NSString *fileName = [self cacheRequestFileName:url];
    NSString *otherInfoFileName = [self cacheRequestOtherInfoFileName:url];
    NSString *filePath = [self cacheFilePath:fileName];
    NSString *fileInfoPath = [self cacheFilePath:otherInfoFileName];
    if (info) {
        return fileInfoPath;
    }
    return filePath;
}

- (NSString *)cacheRequestFileName:(NSString *)requestUrl {
    return [self md5Hash:[NSString stringWithFormat:@"%@",requestUrl]];
}
- (NSString *)cacheRequestOtherInfoFileName:(NSString *)requestUrl {
    return [self md5Hash:[NSString stringWithFormat:@"%@-otherInfo",requestUrl]];
}
- (NSString *)cacheFilePath:(NSString *)file {
    NSString *path = @"URL/CacheDownload";
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir;
    if ([fm fileExistsAtPath:path isDirectory:&isDir] && isDir) {
        //
    } else {
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *diskPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString *subDirPath = [NSString stringWithFormat:@"%@/URL/CacheDownload",diskPath];
    if ([fm fileExistsAtPath:subDirPath isDirectory:&isDir] && isDir) {
        //
    } else {
        [fm createDirectoryAtPath:subDirPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *cFilePath = [NSString stringWithFormat:@"%@/%@",subDirPath,file];
    NSLog(@"%@",cFilePath);
    return cFilePath;
}


#pragma mark - Function Helper
- (NSString *)md5Hash:(NSString *)str {
    const char *cStr = [str UTF8String];
    unsigned char result[16];
    CC_MD5( cStr, (CC_LONG)strlen(cStr), result );
    NSString *md5Result = [NSString stringWithFormat:
                           @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                           result[0], result[1], result[2], result[3],
                           result[4], result[5], result[6], result[7],
                           result[8], result[9], result[10], result[11],
                           result[12], result[13], result[14], result[15]
                           ];
    return md5Result;
}

@end
