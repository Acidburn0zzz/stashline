//
//  AnnuityTrackView.m
//  FinanceLine
//
//  Created by Tristan Hume on 2013-07-08.
//  Copyright (c) 2013 Tristan Hume. All rights reserved.
//

#import "AnnuityTrackView.h"

#define kDefaultHue 0.391
#define kBaseSaturation 0.4
#define kSelectionThickness 4.0
#define kDividerHeight 2.0

@implementation AnnuityTrackView
@synthesize data, hue, selection, selectionDelegate;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
      self.backgroundColor = [UIColor whiteColor];
      hue = kDefaultHue;
      selectionColor = [UIColor blueColor];
      selection = [[Selection alloc] init];
      
      UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panHandler:)];
      [self addGestureRecognizer:pan];
      
      UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
      doubleTap.numberOfTapsRequired = 2;
      [self addGestureRecognizer:doubleTap];
      
      UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTap:)];
      singleTap.numberOfTapsRequired = 1;
      [self addGestureRecognizer:singleTap];
    }
    return self;
}

#pragma mark Selection

- (void)floodSelect:(NSUInteger)month {
  double *dataArr = [data dataPtr];
  double startVal = dataArr[month];
  
  // to the right
  int end;
  for (end = month; end <= kMaxMonth; ++end) {
    if(dataArr[end] != startVal) {
      break;
    }
  }
  end--; // rewind to where we were good
  
  // and to the left
  int start;
  for (start = month; start >= 0; --start) {
    if(dataArr[start] != startVal) {
      break;
    }
  }
  start++; // rewind to where we were good
  
  [selection selectFrom:start to:end];
  
  [selectionDelegate setSelection:selection onTrack:data];
  [self setNeedsDisplay];
}

- (void)selectFrom:(NSUInteger)month to:(NSUInteger)end {
  [selection selectFrom:month to:end];
  [selectionDelegate setSelection:selection onTrack:data];
  [self setNeedsDisplay];
}

- (void)panHandler:(UIPanGestureRecognizer *)sender {
  CGPoint start = [sender locationInView:self];
  CGPoint translation = [sender translationInView:self];
  
  // Selection snaps to current block size
  CGFloat blockSize = [self blockSize];
  NSUInteger startMonth = [self blockForX:start.x] * blockSize;
  NSUInteger endMonth = [self blockForX:start.x-translation.x] * blockSize;
  
  if (endMonth > startMonth) {
    endMonth += (blockSize - 1);
  } else {
    startMonth += (blockSize - 1);
  }
  
  [selection selectFrom:startMonth to:endMonth];
  
  [selectionDelegate setSelection:selection onTrack:data];
  [self setNeedsDisplay];
}

- (void)doubleTap:(UITapGestureRecognizer*)sender {
  if (sender.state == UIGestureRecognizerStateEnded) {
    CGPoint loc = [sender locationInView:self];
    NSUInteger month = [self monthForX:loc.x];
    [self floodSelect:month];
  }
}

- (void)singleTap:(UITapGestureRecognizer*)sender {
  if (sender.state == UIGestureRecognizerStateEnded) {
    CGPoint loc = [sender locationInView:self];
    NSUInteger month = [self monthForX:loc.x];
    
    [selection selectFrom:month to:month];
    [selectionDelegate setSelection:selection onTrack:data];
    [self setNeedsDisplay];
  }
}


#pragma mark Rendering

- (void)splitBlock:(NSUInteger)month ofMonths:(NSUInteger)monthsPerBlock
               atX:(CGFloat)x andScale:(CGFloat)scale withContext:(CGContextRef)context {
  for (int i = 0; i < monthsPerBlock; ++i) {
    [self drawBlock:month+i ofMonths:1 atX:x+(scale*i) andScale:scale withContext:context];
  }
}

- (void)drawBlock:(NSUInteger)month ofMonths:(NSUInteger)monthsPerBlock
              atX:(CGFloat)x andScale:(CGFloat)scale withContext:(CGContextRef)context  {
  // Saturation is average value in block
  double saturation = [data valueFor:month scaledTo:1.0-kBaseSaturation];
  BOOL selected = [selection includes: month];
  
  // Possibly split block render
  BOOL isZero = (saturation == 0.0);
  for (int i = 1; i < monthsPerBlock; ++i) {
    double monthValue = [data valueFor:month+i scaledTo:1.0-kBaseSaturation];
    saturation += monthValue;
    selected = selected || [selection includes:month+i];
    
    if ((monthValue == 0.0) != isZero) {
      [self splitBlock:month ofMonths:monthsPerBlock atX:x andScale:scale withContext:context];
      return;
    }
  }
  saturation /= monthsPerBlock;
  if (saturation > 0.0) {
    saturation += kBaseSaturation;
  }
  
  
  UIColor *boxColour = [UIColor colorWithHue:hue saturation:saturation brightness:1.0 alpha:1.0];
  [boxColour setFill];
  
  CGFloat width = monthsPerBlock * scale;
  
  CGRect rect = self.bounds;
  rect.origin.x = x; rect.origin.y = 0.0;
  rect.size.width = width - 0.2;
  
  CGContextFillRect(context, rect);
  
  // DEBUG
//  int value = [data valueAt:month] * 100;
//  NSString *str = [NSString stringWithFormat:@"%i",value];
//  UIFont *font = [UIFont systemFontOfSize:12.0];
//  [[UIColor blackColor] setFill];
//  [str drawAtPoint:CGPointMake(x, 5.0) withFont:font];
  
  // Draw line above and below if selected
  if (selected) {
    [selectionColor setStroke];
    CGContextSetLineWidth(context, kSelectionThickness);
    CGContextSetLineCap(context, kCGLineCapButt);
    
    CGFloat curY = kSelectionThickness / 2.0;
    CGContextMoveToPoint(context, x, curY);
    CGContextAddLineToPoint(context, x+width, curY);
    CGContextStrokePath(context);
    
    curY = self.bounds.size.height - curY;
    CGContextMoveToPoint(context, x, curY);
    CGContextAddLineToPoint(context, x+width, curY);
    CGContextStrokePath(context);
  }
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
  CGContextRef context = UIGraphicsGetCurrentContext();
  [self drawBlocks:context extraBlock:NO autoScale:YES];
  
  // Draw sidebar
  UIColor *boxColour = [UIColor colorWithHue:hue saturation:1.0 brightness:1.0 alpha:0.5];
  [boxColour setFill];
  
  CGRect r = CGRectMake(0.0, 0.0, 10.0, self.bounds.size.height);
  CGContextFillRect(context, r);
}


@end
