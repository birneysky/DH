//
//  GSComponentDescription.hpp
//  AudioEngine
//
//  Created by birney on 2020/2/28.
//  Copyright © 2020 Pea. All rights reserved.
//

#ifndef GSAudioEngineStructures_hpp
#define GSAudioEngineStructures_hpp

#import <AudioToolbox/AudioToolbox.h>

struct GSComponentDesc : public AudioComponentDescription  {
    GSComponentDesc() {
        memset (this, 0, sizeof (AudioComponentDescription));
    }
    GSComponentDesc (OSType inType, OSType inSubtype = 0, OSType inManu = 0) {
        componentType = inType;
        componentSubType = inSubtype;
        componentManufacturer = inManu;
        componentFlags = 0;
        componentFlagsMask = 0;
    }
};

struct GSScheduledAudioFileRegion: public ScheduledAudioFileRegion {
    GSScheduledAudioFileRegion() {
        memset(this, 0, sizeof(ScheduledAudioFileRegion));
    }
    
    GSScheduledAudioFileRegion(AudioFileID fileId, SInt64 startFrame, UInt32 frames, UInt32 loopCount) {
        memset(this, 0, sizeof(ScheduledAudioFileRegion));
        mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
        mTimeStamp.mSampleTime = 0;
        mAudioFile = fileId;
        mLoopCount = loopCount;
        mStartFrame = startFrame;
        mFramesToPlay = frames;
    }
};

struct GSAudioStreamBasicDesc : public AudioStreamBasicDescription {
    enum CommonPCMFormat {
        kPCMFormatOther        = 0,
        kPCMFormatFloat32    = 1,
        kPCMFormatInt16        = 2,
    };
    
    GSAudioStreamBasicDesc(double inSampleRate, UInt32 inNumChannels, CommonPCMFormat pcmf, bool isInterleaved) {
        memset(this, 0, sizeof(AudioStreamBasicDescription));
        unsigned wordsize;
        mSampleRate = inSampleRate;
        mFormatID = kAudioFormatLinearPCM;
        mFormatFlags = kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
        mFramesPerPacket = 1;
        mChannelsPerFrame = inNumChannels;
        mBytesPerFrame = mBytesPerPacket = 0;
        mReserved = 0;

        switch (pcmf) {
        default:
            return;
        case kPCMFormatFloat32:
            wordsize = 4;
            mFormatFlags |= kAudioFormatFlagIsFloat;
            break;
        case kPCMFormatInt16:
            wordsize = 2;
            mFormatFlags |= kAudioFormatFlagIsSignedInteger;
            break;
        }
        mBitsPerChannel = wordsize * 8;
        if (isInterleaved)
            mBytesPerFrame = mBytesPerPacket = wordsize * inNumChannels;
        else {
            mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
            mBytesPerFrame = mBytesPerPacket = wordsize;
        }
    }
};

struct GSAudioTimeStamp: public AudioTimeStamp {
    GSAudioTimeStamp() {
        memset(this, 0, sizeof(AudioTimeStamp));
        mFlags = kAudioTimeStampSampleTimeValid;
        mSampleTime = -1;
    }
};


#endif 
