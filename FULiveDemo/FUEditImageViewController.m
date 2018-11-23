//
//  FUEditImageViewController.m
//  FULiveDemo
//
//  Created by 孙慕 on 2018/10/9.
//  Copyright © 2018年 L. All rights reserved.
//

#import "FUEditImageViewController.h"
#import "FUNoNullItemsView.h"
#import "FUManager.h"
#import "FULiveModel.h"
#import "SVProgressHUD.h"
#import "FURenderer.h"
#import <FLAnimatedImage/FLAnimatedImage.h>
#import <math.h>

@interface FUEditImageViewController ()<FUItemsViewDelegate>{
    float photoLandmarks[150];
}
@property (weak, nonatomic) IBOutlet FUNoNullItemsView *mItemView;
@property (weak, nonatomic) IBOutlet FLAnimatedImageView *loadingImage;
@property (weak, nonatomic) IBOutlet UIView *mNoFaceView;
@property (weak, nonatomic) IBOutlet UILabel *mTextLabel;
@property (weak, nonatomic) IBOutlet UIButton *OKBtn;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *mLayoutConstraintBottom;
/* 多人脸展示蒙版 */
@property (strong, nonatomic)UIView *maskView;
/* 合成海报是否保存 */
@property (assign, nonatomic)  BOOL isSave;
@property (strong, nonatomic)  NSMutableArray <NSValue *> *array;
/* 返回 */
@property (weak, nonatomic) IBOutlet UIButton *mBackBtn;
/* 下载 */
@property (weak, nonatomic) IBOutlet UIButton *mDownLoadBtn;
@end

@implementation FUEditImageViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [self initializationView];

}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];

    [self setupPhotoMake];
}


-(void)initializationView{
//    _mBackBtn.layer.shadowOpacity = 1.0;
//    _mBackBtn.layer.shadowOffset = CGSizeMake(0, 0);
//    _mBackBtn.layer.shadowColor = [UIColor whiteColor].CGColor;
//    
//    _mDownLoadBtn.layer.shadowOpacity = 1.0;
//    _mDownLoadBtn.layer.shadowOffset = CGSizeMake(0, 0);
    
    [_OKBtn setTitle:NSLocalizedString(@"知道了", nil) forState:UIControlStateNormal];
    if (![[[FUManager shareManager] getPlatformtype] isEqualToString:@"iPhone X"]) {
        _mLayoutConstraintBottom.constant = _mLayoutConstraintBottom.constant - 34;
    }
    
    _mItemView.delegate = self;
    FULiveModel *model = [FUManager shareManager].currentModel;
    
    NSMutableArray *array = [NSMutableArray array];
    for (NSString *str in [FUManager shareManager].currentModel.items) {
        [array addObject:[NSString stringWithFormat:@"%@_icon",str]];
    }
    _mItemView.selectedItem = [NSString stringWithFormat:@"%@_icon",model.items[model.selIndex]];
    
    [_mItemView updateCollectionArray:array];
    self.mImageView.image = [UIImage imageNamed:model.items[model.selIndex]];
    
    NSData *loadingData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"loading.gif" ofType:nil]];
    self.loadingImage.animatedImage = [FLAnimatedImage animatedImageWithGIFData:loadingData];
    self.loadingImage.hidden = YES;
    [self prefersStatusBarHidden];
    [self performSelector:@selector(setNeedsStatusBarAppearanceUpdate)];
    
    _array = [NSMutableArray array];
}


-(void)setupPhotoMake{
    _mImageView.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
    int photoWidth = (int)CGImageGetWidth(_mPhotoImage.CGImage);
    int photoHeight = (int)CGImageGetHeight(_mPhotoImage.CGImage);
    
    CFDataRef photoDataFromImageDataProvider = CGDataProviderCopyData(CGImageGetDataProvider(_mPhotoImage.CGImage));
    GLubyte *photoData = (GLubyte *)CFDataGetBytePtr(photoDataFromImageDataProvider);
    
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    fuOnCameraChange();
    int endI = 0;
    for (int i = 0; i<50; i++) {//校验出人脸再trsckFace 10次
        [FURenderer trackFace:FU_FORMAT_BGRA_BUFFER inputData:photoData width:photoWidth height:photoHeight];
        if ([FURenderer isTracking] > 0) {
            if (endI == 0) {
                endI = i;
            }
            if (i > endI + 10) {
                break;
            }
        }
    }
    CFAbsoluteTime endTime = (CFAbsoluteTimeGetCurrent() - startTime);
    NSLog(@"-------photo----------trackFace: %f ms", endTime * 1000.0);
    
    
    CGRect iamgeAspectRect = AVMakeRectWithAspectRatioInsideRect(_mImageView.image.size, _mImageView.bounds);

    if ([FURenderer isTracking] > 0) {
        if ([FURenderer isTracking] == 1) {
            
            FULiveModel *model = [FUManager shareManager].currentModel;
//            CFAbsoluteTime startTime0 = CFAbsoluteTimeGetCurrent();
            
            if (![self isGoodFace:0]) {
                self.mNoFaceView.hidden = NO;
                if (_PushFrom == FUEditImagePushFromPhoto) {
                    self.mTextLabel.text = NSLocalizedString(@"人脸倾斜大于15°，请重新拍摄",nil);
                }else{
                    self.mTextLabel.text = NSLocalizedString(@"人脸倾斜大于15°，请重新选择",nil);
                }
                return;
            }
            [[FUManager shareManager] getLandmarks:photoLandmarks index:0];
            id warpValue = model.selIndex == 5 ? @0.2 : nil;
            [self productionPoster:[UIImage imageNamed:model.items[model.selIndex]] warpValue:warpValue];

        }else{//多人脸
            /* 添加遮罩选择逻辑 */
            [self addMakeView:[FURenderer isTracking] photoWidth:photoWidth photoHeight:photoHeight iamgeAspectRect:iamgeAspectRect];
        }
        self.mNoFaceView.hidden = YES;
        NSLog(@"111");
    }else{
        self.mNoFaceView.hidden = NO;
    }
    CFRelease(photoDataFromImageDataProvider);
}

-(void)addMakeView:(int)faceNum photoWidth:(int)width photoHeight:(int)height iamgeAspectRect:(CGRect)iamgeAspectRect{
    //创建一个View
    _maskView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [_maskView setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.6]];
    [self.view addSubview:_maskView];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(selectFace:)];
    [self.maskView addGestureRecognizer:tap];
    
    UIButton *tipBtn = [[UIButton alloc] initWithFrame:CGRectMake((_maskView.frame.size.width - 200)/2, 0, 200, 40)];
    [tipBtn setTitle:NSLocalizedString(@"检测到多人，请选择一人进行换脸", nil)  forState:UIControlStateNormal];
    [tipBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    tipBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    tipBtn.contentEdgeInsets = UIEdgeInsetsMake(6, 0, 0, 0);
    [tipBtn setBackgroundImage:[UIImage imageNamed:@"poster_tip"] forState:UIControlStateNormal];
    [tipBtn addTarget:self action:@selector(tipBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.maskView addSubview:tipBtn];
    
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:_maskView.bounds];
    for (int i = 0; i < faceNum; i ++) {
        CGRect rect = [self getFaceRectWithIndex:i photoWidth:width photoHeight:height iamgeAspectRect:iamgeAspectRect];
        UIBezierPath *path1 =  [[UIBezierPath bezierPathWithOvalInRect:rect] bezierPathByReversingPath];// [UIBezierPath bezierPathWithOvalInRect:rect bez];
        [path appendPath:path1];
        
        if (CGRectGetMaxY(rect) > tipBtn.frame.origin.y) {
            tipBtn.frame = CGRectMake((_maskView.frame.size.width - 200)/2, CGRectGetMaxY(rect) + 20, 200, 40);
        }
        
        [_array addObject:[NSValue valueWithCGRect:rect]];
    }
    
    CAShapeLayer *shapeLayer = [CAShapeLayer layer];
    shapeLayer.path = path.CGPath;
    //添加图层蒙板
    _maskView.layer.mask = shapeLayer;
    
}


- (CGRect)getFaceRectWithIndex:(int)index photoWidth:(int)photoWidth photoHeight:(int)photoHeight iamgeAspectRect:(CGRect)iamgeAspectRect{
    float faceRect[4];
    float y;
    [FURenderer getFaceInfo:index name:@"face_rect" pret:faceRect number:4];
    CGFloat centerX = (faceRect[0] + faceRect[2]) * 0.5;
    CGFloat centerY = (faceRect[1] + faceRect[3]) * 0.5;

    centerX =  photoWidth - centerX;
    centerY = photoHeight - centerY;

    CGFloat width = faceRect[2] - faceRect[0] ;
    CGFloat height = faceRect[3] - faceRect[1] ;
    
    float scaleW = iamgeAspectRect.size.width / photoWidth;
    float scaleH = iamgeAspectRect.size.height / photoHeight;
    width  = width * scaleW;
    height = height * scaleH;
    
    y = centerY * scaleH - height/2 + iamgeAspectRect.origin.y;
//    y = [[[FUManager shareManager] getPlatformtype] isEqualToString:@"iPhone X"] ? centerY * scaleH - height/2 + iamgeAspectRect.origin.y + 44 : centerY * scaleH - height/2 + iamgeAspectRect.origin.y;
   CGRect rect = CGRectMake(centerX * scaleW - width/2 + iamgeAspectRect.origin.x , y, width, height);

    NSLog(@"输出结果----%@",NSStringFromCGRect(rect));
    
    return rect;
}


-(void)itemsViewDidSelectedItem:(NSString *)item{
    _isSave = NO;
    [_mItemView stopAnimation];
    NSArray *array = [item componentsSeparatedByString:@"_"];
    id warpValue = [array[0] isEqualToString:@"poster6"] ? @0.2 : nil;
    [self productionPoster:[UIImage imageNamed:array[0]] warpValue:warpValue];
}



-(void)setMPhotoImage:(UIImage *)mPhotoImage{
    NSData *imageData = UIImageJPEGRepresentation(mPhotoImage, 1.0);
    mPhotoImage = [UIImage imageWithData:imageData];
    _mPhotoImage = mPhotoImage;
    self.mImageView.image = mPhotoImage;
    
    if (_PushFrom == FUEditImagePushFromAlbum) {
        _mTextLabel.text = NSLocalizedString(@"未检测出人脸，请重新上传",nil);
    }else{
        _mTextLabel.text = NSLocalizedString(@"未检测出人脸，请重新拍摄",nil); 
    }

}

-(void)productionPoster:(UIImage *)posterImage warpValue:(id)warpValue{
    self.loadingImage.hidden = NO;
    self.view.userInteractionEnabled = NO;
    __block UIImage * posterImagen = posterImage;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        UIImage *photoImage = self.mPhotoImage;
        if (!photoImage || !posterImage) {
            return ;
        }
        [[FUManager shareManager] productionPoster:posterImage photo:photoImage photoLandmarks:photoLandmarks warpValue:warpValue];
        posterImagen = [[FUManager shareManager] renderItemsToImage:posterImagen];

        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.mImageView.image = posterImagen;
            self.loadingImage.hidden = YES;
            self.view.userInteractionEnabled = YES;
        });
        
    });
    
}


//保证正脸
-(BOOL)isGoodFace:(int)index{
    // 保证正脸
    float rotation[4] ;
    float DetectionAngle = 15.0 ;
    [FURenderer getFaceInfo:index name:@"rotation" pret:rotation number:4];
    
//    float xAngle = atanf(2 * (rotation[3] * rotation[0] + rotation[1] * rotation[2]) / (1 - 2 * (rotation[0] * rotation[0] + rotation[1] * rotation[1]))) * 180 / M_PI;
//    float yAngle = asinf(2 * (rotation[1] * rotation[3] - rotation[0] * rotation[2])) * 180 / M_PI;
//    float zAngle = atanf(2 * (rotation[3] * rotation[2] + rotation[0] * rotation[1]) / (1 - 2 * (rotation[1] * rotation[1] + rotation[2] * rotation[2]))) * 180 / M_PI;
//
//    if (xAngle < -DetectionAngle || xAngle > DetectionAngle
//        || yAngle < -DetectionAngle || yAngle > DetectionAngle
//        || zAngle < -DetectionAngle || zAngle > DetectionAngle) {
//
//        return NO ;
//    }
    
    float q0 = rotation[0];
    float q1 = rotation[1];
    float q2 = rotation[2];
    float q3 = rotation[3];

    float z =  atan2(2*(q0*q1 + q2 * q3), 1 - 2*(q1 * q1 + q2 * q2)) * 180 / M_PI;
    float y =  asin(2 *(q0*q2 - q1*q3)) * 180 / M_PI;
    float x = atan(2*(q0*q3 + q1*q2)/(1 - 2*(q2*q2 + q3*q3))) * 180 / M_PI;
    NSLog(@"x=%lf  y=%lf z=%lf",x,y,z);
    if (x > DetectionAngle || x < - 5 || fabs(y) > DetectionAngle || fabs(z) > DetectionAngle) {//抬头低头角度限制：仰角不大于5°，俯角不大于15°
        return NO;
    }

    return YES;
}


#pragma  mark ----  UI Action  -----

- (IBAction)backAction:(id)sender {
    [self.navigationController popToViewController:self.navigationController.viewControllers[1] animated:YES];
    [[FUManager shareManager] destroyItemPoster];
    
}

/* 保存图片 */
- (IBAction)loadAction:(id)sender {
    
    if (_mImageView.image) {
        if (_isSave) {
             [SVProgressHUD showSuccessWithStatus:NSLocalizedString(@"图片已保存到相册", nil)];
            return;
        }
        UIImageWriteToSavedPhotosAlbum(_mImageView.image, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
    }
    
}

-(void)tipBtnClick:(UIButton *)btn{
  //  [_maskView removeFromSuperview];
}

// 选择某一张脸
- (void)selectFace:(UITapGestureRecognizer *)tap {
    CGPoint point = [tap locationInView:self.maskView] ;
    for (NSValue *value in _array) {
        CGRect rect = [value CGRectValue];
        if (CGRectContainsPoint(rect,point)) {
            [_maskView removeFromSuperview];
            int index = (int)[_array indexOfObject:value];
            FULiveModel *model = [FUManager shareManager].currentModel;
            if (![self isGoodFace:index]) {
                self.mNoFaceView.hidden = NO;
                if (_PushFrom == FUEditImagePushFromPhoto) {
                    self.mTextLabel.text = NSLocalizedString(@"人脸倾斜大于15°，请重新拍摄",nil);
                }else{
                    self.mTextLabel.text = NSLocalizedString(@"人脸倾斜大于15°，请重新选择",nil);
                }
                return;
            }
            [[FUManager shareManager] getLandmarks:photoLandmarks index:index];
            id warpValue = model.selIndex == 5 ? @0.2 : nil;
            [self productionPoster:[UIImage imageNamed:model.items[model.selIndex]] warpValue:warpValue];
            NSLog(@"rect[0] ---%lf ,photoLa[0] = %lf ",rect.origin.x, photoLandmarks[0]);
         //   return;
        }
    }
}
- (IBAction)knownAction:(id)sender {
    
    [self.navigationController popToViewController:self.navigationController.viewControllers[2] animated:YES];
}

- (void)image: (UIImage *) image didFinishSavingWithError: (NSError *) error contextInfo: (void *) contextInfo
{
    if(error != NULL){
        [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"保存图片失败", nil)];
    }else{
        _isSave = YES;
        [SVProgressHUD showSuccessWithStatus:NSLocalizedString(@"图片已保存到相册", nil)];
    }
}

#pragma  mark ----  重载系统方法  -----
- (BOOL)prefersStatusBarHidden
{
    return YES;//隐藏为YES，显示为NO
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)dealloc{
    [[FUManager shareManager] destoryItem:2];//销毁海报
}

@end
