//
//  ViewController.m
//  STMURLCache
//
//  Created by daiming on 2016/11/17.
//  Copyright © 2016年 Starming. All rights reserved.
//

#import "ViewController.h"
#import <AFNetworking/AFNetworking.h>
#import <Masonry/Masonry.h>
#import "STMURLCache.h"

@interface ViewController ()<UIWebViewDelegate>
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) STMURLCache *sCache;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *whiteListStr = @"www.starming.com|www.github.com|www.v2ex.com|www.baidu.com";
    
    NSMutableArray *whiteLists = [NSMutableArray arrayWithArray:[whiteListStr componentsSeparatedByString:@"|"]];
    whiteLists = nil;
    self.sCache = [STMURLCache create:^(STMURLCacheMk *mk) {
        mk.whiteListsHost(whiteLists).whiteUserAgent(@"starming");
    }];
    
    [self.sCache update:^(STMURLCacheMk *mk) {
        mk.isDownloadMode(YES);
    }];
    [self.sCache preLoadByWebViewWithUrls:@[@"http://www.v2ex.com",@"http://www.github.com",@"http://www.starming.com"]];
    //    [self.sCache preLoadByRequestWithUrls:@[@"http://www.github.com",@"http://www.baidu.com"]];
    
    //    [self.sCache stop];
    
    //------------web view 加载区域-----------
    self.webView = [[UIWebView alloc] init];
    
    [self.view addSubview:self.webView];
    [self.webView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.bottom.equalTo(self.view);
    }];
    self.webView.delegate = self;
    NSURLRequest *re = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.github.com"]];
    [self.webView loadRequest:re];
}


@end
