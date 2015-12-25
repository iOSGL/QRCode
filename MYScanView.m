//
//  MYScanView.m
//  CoreAnimationTest
//
//  Created by geng lei on 15/11/23.
//  Copyright © 2015年 com.fengche.cn. All rights reserved.
//

#import "MYScanView.h"
#import <AVFoundation/AVFoundation.h>
#import <Masonry/Masonry.h>
#define SCAN_SPACE_OFFSET 0.1f
#define REMIND_TEXT @"将二维码/条码放入框内，即可自动扫描"
#define SCREEN_BOUNDS [UIScreen mainScreen].bounds
#define SCREEN_WIDTH CGRectGetWidth([UIScreen mainScreen].bounds)
#define SCREEN_HEIGHT CGRectGetHeight([UIScreen mainScreen].bounds)
#define REMIND_TEXT @"将二维码/条码放入框内，即可自动扫描"
#define LINE_SCAN_TIME  3.0     // 扫描线从上到下扫描所历时间（s）
@interface MYScanView()<AVCaptureMetadataOutputObjectsDelegate>
/**
 *  管理输入(AVCaptureInput)和输出(AVCaptureOutput)流，包含开启和停止会话方法。
 */
@property (nonatomic, strong) AVCaptureSession *captureSession;
/**
 *  设备输入类。这个类用来表示输入数据的硬件设备，配置抽象设备的port
 */
@property (nonatomic, strong) AVCaptureDeviceInput *deviceInput;
/**
 *   输出类。这个支持二维码、条形码等图像数据的识别
 */
@property (nonatomic, strong) AVCaptureMetadataOutput *metadataOutput;
/**
 *  CALayer的一个子类，显示捕获到的相机输出流。
 */
@property (nonatomic ,strong) AVCaptureVideoPreviewLayer *previewLayer;
/**
 *  提示信息
 */
@property (nonatomic, strong) UILabel *infoLable;
/**
 *  计时器
 */
@property (nonatomic, strong) NSTimer *scanTimer;
/**
 *  闪光灯
 */
@property (nonatomic, strong) UIButton *touchSwitch;
/**
 *  <#Description#>
 */
@property (nonatomic, strong) CAShapeLayer * maskLayer;
/**
 *  阴影层
 */
@property (nonatomic, strong) CAShapeLayer * shadowLayer;
/**
 *  扫描框
 */
@property (nonatomic, strong) CAShapeLayer * scanRectLayer;
/**
 *  设置扫描范围
 */
@property (nonatomic, assign) CGRect scanRect;
/**
 *  返回按钮
 */
@property (nonatomic, strong) UIButton *touchBack;
/**
 *  取景框的角图
 */
@property (nonatomic, strong) UIImageView *topLeft;
@property (nonatomic, strong) UIImageView *topRight;
@property (nonatomic, strong) UIImageView *bottomLeft;
@property (nonatomic, strong) UIImageView *bottomRight;
/**
 *  上下移动的线
 */
@property (nonatomic, strong) UIImageView *scanLineImageView;
@end
@implementation MYScanView
#pragma mark - Life Cyle
+ (instancetype)createScanViewInController:(UIViewController *)controller scanBounds:(CGRect)rect {
    if (!controller) {
        return nil;
    }
    MYScanView *scanView = [[MYScanView alloc]initWithFrame:rect];
    if ([controller conformsToProtocol:@protocol(MYScanViewDelegate)] ) {
        scanView.delegate = (UIViewController<MYScanViewDelegate> *)controller;
    }
    return scanView;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.f alpha:0.2f];
        [self.layer addSublayer:self.previewLayer];
        [self setupScanRect];
        [self addSubview:self.infoLable];
        [self addSubview:self.touchBack];
        [self.touchBack mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self).with.offset(20);
            make.top.equalTo(self).with.offset(20);
            make.size.mas_equalTo(CGSizeMake(36, 36));
        }];
        [self addSubview:self.touchSwitch];
        [self.touchSwitch mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self).with.offset(-20);
            make.top.equalTo(self).with.offset(20);
            make.size.mas_equalTo(CGSizeMake(36, 36));
        }];
        [self addSubview:self.topLeft];
        /* 画一个取景框开始 */
        // 正方形取景框的边长

        CGRect rect = self.scanRect;
         rect.origin.y = rect.origin.y;
        CGFloat edgeLength = 20.0;
        [self.topLeft mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self).with.offset(rect.origin.x);
            make.top.equalTo(self).with.offset(rect.origin.y);
            make.size.mas_equalTo(CGSizeMake(edgeLength, edgeLength));
        }];
        
        [self addSubview:self.topRight];
        [self.topRight mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self).with.offset(-rect.origin.x);
            make.top.equalTo(self).with.offset(rect.origin.y);
            make.size.mas_equalTo(CGSizeMake(edgeLength, edgeLength));
        }];
        
        [self addSubview:self.bottomLeft];
        [self.bottomLeft mas_makeConstraints:^(MASConstraintMaker *make) {
            make.bottom.equalTo(self).with.offset(-(SCREEN_HEIGHT-(rect.origin.y+rect.size.height)));
            make.left.equalTo(self.topLeft.mas_left);
            make.size.mas_equalTo(CGSizeMake(edgeLength, edgeLength));
        }];

        [self addSubview:self.bottomRight];
        [self.bottomRight mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self.topRight.mas_right);
            make.bottom.equalTo(self.bottomLeft.mas_bottom);
            make.size.mas_equalTo(CGSizeMake(edgeLength, edgeLength));
        }];
        
        [self addSubview:self.scanLineImageView];
        [self.scanLineImageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self).with.offset(rect.origin.y);
            make.centerX.equalTo(self.mas_centerX);
            make.size.mas_equalTo(CGSizeMake(230, 10));
            
        }];
        
        self.layer.masksToBounds = YES;
        
    }
    return self;
}
/**
 *  释放前停止会话
 */
- (void)dealloc {
    [self stopScan];
}
#pragma mark - AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    if(metadataObjects.count>0) {
        [self stopScan];
        AVMetadataMachineReadableCodeObject *metadaObject = metadataObjects[0];
        
        debugLog(@"output:%@", metadaObject.stringValue);
        if ([self.delegate respondsToSelector:@selector(didFishedRedingQRCode:)]) {
            [self.delegate didFishedRedingQRCode:metadaObject.stringValue];
            [self removeFromSuperview];
        }
    }
}
#pragma mark - MYCodeRederViewControllerDelegate;
#pragma mark - Open Method
- (void)stardScan {
    [self.captureSession startRunning];
}
- (void)stopScan {
    [self.captureSession stopRunning];
}
- (void)stardMove {
    if (!self.scanTimer) {
        
        [self moveScanLine];
        [self createTimer];
    }
}
#pragma mark - Private Method;
- (void)createTimer {
    self.scanTimer = [NSTimer scheduledTimerWithTimeInterval:LINE_SCAN_TIME target:self selector:@selector(moveScanLine) userInfo:nil repeats:YES];
}

- (void)moveScanLine {
    self.scanLineImageView.hidden = NO;
    CGRect rect = self.scanRect;
    rect.origin.y = rect.origin.y;
    [self.scanLineImageView setNeedsLayout];
    // 往下移动
    [self.scanLineImageView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self).with.offset(rect.origin.y+rect.size.height);
    }];
    [UIView animateWithDuration:LINE_SCAN_TIME-0.05 animations:^{
    [self.scanLineImageView layoutIfNeeded];
        
    } completion:^(BOOL finished) {
        self.scanLineImageView.hidden = YES;
        [self.scanLineImageView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self).with.offset(rect.origin.y);
        }];
        [UIView animateWithDuration:0 animations:^{
            [self.scanLineImageView layoutIfNeeded];
        }];

    }];
    
    }
/**
 *  配置输入输出设置
 */
- (void)setupIODevice
{
    if ([self.captureSession canAddInput: self.deviceInput]) {
        [self.captureSession addInput: self.deviceInput];
    }
    if ([self.captureSession canAddOutput: self.metadataOutput]) {
        [self.captureSession addOutput: self.metadataOutput];
        self.metadataOutput.metadataObjectTypes = @[AVMetadataObjectTypeQRCode, AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code];
    }
}
/**
 *  配置扫描范围
 */
- (void)setupScanRect {
    // 扫描框的宽度
    CGFloat size = SCREEN_WIDTH * (1 - 2 * SCAN_SPACE_OFFSET);
    CGFloat minY = (SCREEN_HEIGHT - size) * 0.5 / SCREEN_HEIGHT;
    CGFloat maxY = (SCREEN_HEIGHT + size ) * 0.5 / SCREEN_HEIGHT;
    self.metadataOutput.rectOfInterest = CGRectMake(minY, SCAN_SPACE_OFFSET, maxY, 1 - SCAN_SPACE_OFFSET * 2);
    [self.layer addSublayer: self.shadowLayer];
    [self.layer addSublayer: self.scanRectLayer];
}
/**
 *  生成空缺部分rect的layer
 */
- (CAShapeLayer *)generateMaskLayerWithRect: (CGRect)rect exceptRect: (CGRect)exceptRect
{
    CAShapeLayer * maskLayer = [CAShapeLayer layer];
    if (!CGRectContainsRect(rect, exceptRect)) {
        return nil;
    }
    else if (CGRectEqualToRect(rect, CGRectZero)) {
        maskLayer.path = [UIBezierPath bezierPathWithRect: rect].CGPath;
        return maskLayer;
    }
    
    CGFloat boundsInitX = CGRectGetMinX(rect);
    CGFloat boundsInitY = CGRectGetMinY(rect);
    CGFloat boundsWidth = CGRectGetWidth(rect);
    CGFloat boundsHeight = CGRectGetHeight(rect);
    
    CGFloat minX = CGRectGetMinX(exceptRect);
    CGFloat maxX = CGRectGetMaxX(exceptRect);
    CGFloat minY = CGRectGetMinY(exceptRect);
    CGFloat maxY = CGRectGetMaxY(exceptRect);
    CGFloat width = CGRectGetWidth(exceptRect);
    
    /** 添加路径*/
    UIBezierPath * path = [UIBezierPath bezierPathWithRect: CGRectMake(boundsInitX, boundsInitY, minX, boundsHeight)];
    [path appendPath: [UIBezierPath bezierPathWithRect: CGRectMake(minX, boundsInitY, width, minY)]];
    [path appendPath: [UIBezierPath bezierPathWithRect: CGRectMake(maxX, boundsInitY, boundsWidth - maxX, boundsHeight)]];
    [path appendPath: [UIBezierPath bezierPathWithRect: CGRectMake(minX, maxY, width, boundsHeight - maxY)]];
    maskLayer.path = path.CGPath;
    
    return maskLayer;
}

#pragma mark - Event Responce;
- (void)actionBack:(UIButton *)sender {
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(actionBack)]) {
        [self.delegate actionBack];
    }
}
- (void)torchSwitch:(UIButton *)sender {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error;
    if (device.hasFlash) {//判断是否有闪光灯
        BOOL isSupport = [device lockForConfiguration:&error];
        if (!isSupport) {
            if (error) {
                NSLog(@"lock torch configuration error:%@", error.localizedDescription);
            }
            return;
        }
        device.torchMode = (device.torchMode == AVCaptureTorchModeOff ? AVCaptureTorchModeOn : AVCaptureTorchModeOff);
        [device unlockForConfiguration];
    }
}
#pragma mark - Setter - Getter
/**
 *  会话对象
 */
- (AVCaptureSession *)captureSession {
    if (!_captureSession) {
        _captureSession = [AVCaptureSession new];
        [_captureSession setSessionPreset:AVCaptureSessionPresetHigh];
        [self setupIODevice];
    }
    return _captureSession;
}
/**
 *  视频输入设备
 */
- (AVCaptureDeviceInput *)deviceInput {
    if (!_deviceInput) {
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        NSError *error =nil;
        _deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
        if (error) {
            NSLog(@"警告：该设备是模拟器，并没有摄像头！");
            return nil;
        }
    }
    return _deviceInput;
}
/**
 *  数据输出对象
 */
- (AVCaptureMetadataOutput *)metadataOutput {
    if (!_metadataOutput) {
        _metadataOutput = [AVCaptureMetadataOutput new];
        [_metadataOutput setMetadataObjectsDelegate: self queue:dispatch_get_main_queue()];
    }
    return _metadataOutput;
}
/**
 *  扫描视图
 */
- (AVCaptureVideoPreviewLayer *)previewLayer{
    if (!_previewLayer) {
        _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
        _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        _previewLayer.frame = self.bounds;
    }
    return _previewLayer;
}
- (CAShapeLayer *)shadowLayer {
    if (!_shadowLayer) {
        _shadowLayer = [CAShapeLayer layer];
        _shadowLayer.path = [UIBezierPath bezierPathWithRect:self.bounds].CGPath;
        _shadowLayer.fillColor = [UIColor colorWithWhite:0.f alpha:0.75f].CGColor;
        _shadowLayer.mask = self.maskLayer;
    }
    return _shadowLayer;
}
- (CAShapeLayer *)maskLayer {
    if (!_maskLayer) {
        _maskLayer = [CAShapeLayer layer];
        _maskLayer = [self generateMaskLayerWithRect:self.bounds exceptRect:self.scanRect];
    }
    return _maskLayer;
}
/**
 *  扫描范围
 */
- (CGRect)scanRect
{
    if (CGRectEqualToRect(_scanRect, CGRectZero)) {
        CGRect rectOfInterest = self.metadataOutput.rectOfInterest;
        CGFloat yOffset = rectOfInterest.size.width - rectOfInterest.origin.x;
        CGFloat xOffset = 1 - 2 * SCAN_SPACE_OFFSET;
        _scanRect = CGRectMake(rectOfInterest.origin.y * SCREEN_WIDTH, rectOfInterest.origin.x * SCREEN_HEIGHT, xOffset * SCREEN_WIDTH, yOffset * SCREEN_HEIGHT);
    }
    return _scanRect;
}
/**
 *  扫描框
 */
- (CAShapeLayer *)scanRectLayer
{
    if (!_scanRectLayer) {
        CGRect scanRect = self.scanRect;
        scanRect.origin.x -= 1;
        scanRect.origin.y -= 1;
        scanRect.size.width += 2;
        scanRect.size.height += 2;
        
        _scanRectLayer = [CAShapeLayer layer];
        _scanRectLayer.path = [UIBezierPath bezierPathWithRect: scanRect].CGPath;
        _scanRectLayer.fillColor = [UIColor clearColor].CGColor;
        _scanRectLayer.strokeColor = [UIColor orangeColor].CGColor;
    }
    return _scanRectLayer;
}
- (UILabel *)infoLable {
    if (!_infoLable) {
        CGRect textRect = self.scanRect;
        textRect.origin.y += CGRectGetHeight(textRect) + 20;
        textRect.size.height = 25.0f;
        
        _infoLable = [[UILabel alloc]initWithFrame:textRect];
        _infoLable.font = [UIFont systemFontOfSize:15.f * SCREEN_WIDTH / 375.f];
        _infoLable.textColor = [UIColor whiteColor];
        _infoLable.textAlignment = NSTextAlignmentCenter;
        _infoLable.text = REMIND_TEXT;
        _infoLable.backgroundColor = [UIColor clearColor];
    }
    return _infoLable;
}
- (UIButton *)touchBack {
    if (!_touchBack) {
        _touchBack = [UIButton buttonWithType:UIButtonTypeCustom];
        [_touchBack setImage:[UIImage imageNamed:@"qr_vc_left"] forState:UIControlStateNormal];
        _touchBack.layer.cornerRadius = 18.0;
        _touchBack.layer.backgroundColor = [[UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5] CGColor];
        [_touchBack addTarget:self action:@selector(actionBack:) forControlEvents:UIControlEventTouchDown];
        
    }
    return _touchBack;
}
- (UIButton *)touchSwitch {
    if (!_touchSwitch) {
        _touchSwitch = [UIButton buttonWithType:UIButtonTypeCustom];
        [_touchSwitch setImage:[UIImage imageNamed:@"qr_vc_right"] forState:UIControlStateNormal];
        _touchSwitch.layer.cornerRadius = 18;
        _touchSwitch.layer.backgroundColor = [[UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5] CGColor];
        [_touchSwitch addTarget:self action:@selector(torchSwitch:) forControlEvents:UIControlEventTouchDown];
    }
    return _touchSwitch;
}
- (UIImageView *)topLeft {
    if (!_topLeft) {
        _topLeft = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"qr_top_left"]];
    }
    return _topLeft;
}
- (UIImageView *)topRight {
    if (!_topRight) {
        _topRight = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"qr_top_right"]];
    }
    return _topRight;
}
- (UIImageView *)bottomLeft {
    if (!_bottomLeft) {
        _bottomLeft = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"qr_bottom_left"]];
    }
    return _bottomLeft;
}
- (UIImageView *)bottomRight {
    if (!_bottomRight) {
        _bottomRight = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"qr_bottom_right"]];
    }
    return _bottomRight;
}
- (UIImageView *)scanLineImageView {
    if (!_scanLineImageView) {
        _scanLineImageView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"qr_scan_line"]];
    }
    return _scanLineImageView;
}
@end
