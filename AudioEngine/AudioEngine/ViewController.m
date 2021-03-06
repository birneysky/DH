//
//  ViewController.m
//  AudioEngine
//
//  Created by birney on 2020/2/27.
//  Copyright © 2020 Pea. All rights reserved.
//

@import AVFoundation;
#import "ViewController.h"
#import "GSAudioEngine.h"
#import "GSAudioMixerNode.h"
#import "GSAudioOutputNode.h"
#import "GSAudioPlayerNode.h"
#import "GSAudioInputNode.h"

@interface ViewController ()


@property (nonatomic, strong) GSAudioEngine* engine;
@property (nonatomic, strong) GSAudioMixerNode* mixer;
@property (nonatomic, strong) GSAudioPlayerNode* player1;
@property (nonatomic, strong) GSAudioPlayerNode* player2;

@end

@implementation ViewController

#pragma mark - init

- (void)viewDidLoad {
    [super viewDidLoad];
    [self configureAudioSession];

    GSAudioOutputNode* outputNode = self.engine.outputNode;
    GSAudioInputNode* inputNode = self.engine.inputNode;
    //[self.engine attach:self.player1];
    //[self.engine attach:self.player2];
    [self.engine attach:self.mixer];
    //[self.engine attach:self.outputNode];
    //[self.engine attach:outputNode];
    
//    [self.engine connect:inputNode to:outputNode];
    [self.engine connect:inputNode to:self.mixer];
 //   [self.engine connect:self.player1 to:self.mixer];
//    [self.engine connect:self.player2 to:self.mixer];
//    [self.engine connect:inputNode to:self.mixer];
    //[self.engine connect:self.inputNode to:self.mixer];
    [self.engine connect:self.mixer to:outputNode];
        
    [self.engine prepare];
    
}

#pragma mark - Helper
- (void)configureAudioSession {
    AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
    NSError *error = nil;
    //[sessionInstance setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    [sessionInstance setCategory:AVAudioSessionCategoryPlayAndRecord   error:nil];
    NSTimeInterval bufferDuration = .005;
    [sessionInstance setPreferredIOBufferDuration:bufferDuration error:&error];
//    [sessionInstance setMode:AVAudioSessionModeDefault error:nil];
    [sessionInstance setPreferredSampleRate:48000 error:&error];
    [sessionInstance setActive:YES error:&error];

    
}

#pragma mark - tareget actions

- (IBAction)switchSpeaker:(UIButton *)sender {
   // [self.engine stop];
    if (!sender.isSelected) {
        AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
        //[sessionInstance setActive:NO error:nil];
//        [sessionInstance setCategory:AVAudioSessionCategoryPlayAndRecord  error:nil];
//        NSTimeInterval bufferDuration = .005;
//        [sessionInstance setPreferredIOBufferDuration:bufferDuration error:nil];
        [sessionInstance setMode:AVAudioSessionModeVideoChat error:nil];
 //       [sessionInstance setPreferredSampleRate:441000 error:nil];
 //       [sessionInstance overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
        NSLog(@"speaker:%lf",sessionInstance.sampleRate);
        //[sessionInstance setActive:YES error:nil];
        sender.selected = YES;
    } else {
        AVAudioSession *sessionInstance = [AVAudioSession sharedInstance];
        //[sessionInstance setActive:NO error:nil];
 //       [sessionInstance setCategory:AVAudioSessionCategoryPlayAndRecord   error:nil];
//        NSTimeInterval bufferDuration = .005;
//        [sessionInstance setPreferredIOBufferDuration:bufferDuration error:nil];
        [sessionInstance setMode:AVAudioSessionModeVoiceChat error:nil];
//        [sessionInstance setPreferredSampleRate:441000 error:nil];
      //  [sessionInstance setPreferredSampleRate:sessionInstance.sampleRate error:nil];
        //[[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
         //[sessionInstance setMode:AVAudioSessionModeVoiceChat error:nil];
               // [sessionInstance setActive:YES error:nil];
        NSLog(@"none:%lf",sessionInstance.sampleRate);
        sender.selected = NO;
    }
 //   [self.engine start];
}
- (IBAction)startAction:(UIButton *)sender {
    if (!sender.isSelected) {
        [self.engine start];
        sender.selected = YES;
    } else {
        [self.engine stop];
        sender.selected = NO;
    }
}
- (IBAction)player1SwithPress:(UISwitch *)sender {
    if (sender.on) {
        [self.player1 play];
    } else {
        [self.player1 pause];
    }
}
- (IBAction)player2SwitchPress:(UISwitch *)sender {
    if (sender.on) {
        [self.player2 play];
    } else {
        [self.player2 pause];
    }
}

- (IBAction)alterPlayer1Volume:(UISlider *)sender {
    self.player1.inputVolume = sender.value;
}

- (IBAction)alterPlayer2Volume:(UISlider*)sender {
    self.player2.inputVolume = sender.value;
}

#pragma mark - Getters
- (GSAudioEngine*) engine {
    if (!_engine) {
        _engine = [[GSAudioEngine alloc] init];
    }
    return _engine;
}

- (GSAudioMixerNode*)mixer {
    if (!_mixer) {
        _mixer = [[GSAudioMixerNode alloc] init];
    }
    return _mixer;
}

- (GSAudioPlayerNode*)player1 {
    if (!_player1) {
        NSString* path = [[NSBundle mainBundle] pathForResource:@"guitar" ofType:@"m4a"];
        NSURL* fileUrl = [NSURL fileURLWithPath:path];
        _player1 = [[GSAudioPlayerNode alloc] initWithFileURL:fileUrl];
    }
    return _player1;
}


- (GSAudioPlayerNode*)player2 {
    if (!_player2) {
        NSString* path = [[NSBundle mainBundle] pathForResource:@"band" ofType:@"m4a"];
        NSURL* fileUrl = [NSURL fileURLWithPath:path];
        _player2 = [[GSAudioPlayerNode alloc] initWithFileURL:fileUrl];
    }
    return _player2;
}


@end
