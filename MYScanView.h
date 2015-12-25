//
//  MYScanView.h
//  CoreAnimationTest
//
//  Created by geng lei on 15/11/23.
//  Copyright © 2015年 com.fengche.cn. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol MYScanViewDelegate <NSObject>

@optional
/**
 *  传递扫描信息
 */
- (void)didFishedRedingQRCode:(NSString *)QRMessage;
/**
 *  返回事件
 */
- (void)actionBack;

@end

@interface MYScanView : UIView
/**
 *  在controller中实例化MYScanView
 *
 *  @param controller <#controller description#>
 *
 *  @return MYScanView
 */
+ (instancetype)createScanViewInController:(UIViewController *)controller scanBounds:(CGRect)rect;
/**
 *
 */
@property (nonatomic, weak) id<MYScanViewDelegate>delegate;
/**
 *  开始扫描
 */
- (void)stardScan;
/**
 *  停止扫描
 */
- (void)stopScan;
/**
 *  开始移动
 */
- (void)stardMove;
@end
