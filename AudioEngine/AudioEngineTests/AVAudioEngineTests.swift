//
//  AVAudioEngineTests.swift
//  AudioEngineTests
//
//  Created by birney on 2020/2/28.
//  Copyright © 2020 Pea. All rights reserved.
//

import XCTest
import AVFoundation
import AudioToolbox
import AudioUnit

func printASBD(asbd: UnsafePointer<AudioStreamBasicDescription>)  {
 
    let aasbd = asbd.pointee;
    var formatID = CFSwapInt32HostToBig (aasbd.mFormatID);
    let formatIDRaw = UnsafeMutableRawPointer.allocate(byteCount: 5,
                                                       alignment: 0);
    formatIDRaw.initializeMemory(as: Int8.self,
                                 repeating: 0,
                                 count: 5)
    bcopy (&formatID, formatIDRaw, 4);
    let formatIDString = String(bytesNoCopy: formatIDRaw,
                                length: 5,
                                encoding: .ascii,
                                freeWhenDone: false)
    formatIDRaw.deallocate()
 
    print ("  Sample Rate:         \(aasbd.mSampleRate)" )
    print ("  Format ID:           \(formatIDString ?? "unkown")")
    print ("  Format Flags:        \(aasbd.mFormatFlags)")
    print ("  Bytes per Packet:    \(aasbd.mBytesPerPacket)")
    print ("  Frames per Packet:   \(aasbd.mFramesPerPacket)")
    print ("  Bytes per Frame:     \(aasbd.mBytesPerFrame)")
    print ("  Channels per Frame:  \(aasbd.mChannelsPerFrame)")
    print ("  Bits per Channel:    \(aasbd.mBitsPerChannel)")
}

func inputCallback(inRefCon: UnsafeMutableRawPointer,
                   flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                   timestamp: UnsafePointer<AudioTimeStamp>,
                   busNumber:UInt32,
                   numFrames:UInt32,
                   ioData:UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
    NSLog("busNumber \(busNumber) numberFrames \(numFrames)")
    let unit: AudioUnit = unsafeBitCast(inRefCon, to: AudioUnit.self)
    var format = AudioStreamBasicDescription()
    var size:UInt32 = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    
    assert(AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat,
                                kAudioUnitScope_Output, busNumber,
                                &format, &size) == noErr)
    
    let data = Array<UInt8>(repeating: 0, count: Int(numFrames * format.mBytesPerFrame))
    let buffer = AudioBuffer(mNumberChannels: 1,
                             mDataByteSize: numFrames * format.mBytesPerFrame,
                             mData: UnsafeMutableRawPointer(mutating: data))
    var bufferList = AudioBufferList(mNumberBuffers: 1,
                                     mBuffers: (buffer))
    
    assert(AudioUnitRender(unit, flags, timestamp, busNumber,
                           numFrames, &bufferList) == noErr)
    /*
    print("=======================")
    for val in data {
        print(String(format:"%02x", val), terminator:",")
    }
    print("\n=======================")*/
    return noErr
}


class AVAudioEngineTests: XCTestCase {

    let engine = AVAudioEngine()
    let engine1 = AVAudioEngine()
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let session = AVAudioSession.sharedInstance()

         do {
             try session.setCategory(.playAndRecord)
             try session.setPreferredSampleRate(44100)
            try session.setPreferredIOBufferDuration(0.005)
             try session.setActive(true)
         } catch {
             print("desc:\(error.localizedDescription)")
         }
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testAudioUnitRecord() {
    
        var acdesc = AudioComponentDescription()
        acdesc.componentType =         kAudioUnitType_Output
        acdesc.componentSubType =      kAudioUnitSubType_RemoteIO
        acdesc.componentManufacturer = kAudioUnitManufacturer_Apple
        acdesc.componentFlags =        0
        acdesc.componentFlagsMask =    0
        
        if let component =  AudioComponentFindNext(nil, &acdesc) {
            var audioUnit: AudioComponentInstance? = nil
            AudioComponentInstanceNew(component, &audioUnit)
            guard let aUnit = audioUnit else {
                fatalError()
            }
            var enable: UInt32 = 1
            assert(AudioUnitSetProperty(aUnit, kAudioOutputUnitProperty_EnableIO,
                                        kAudioUnitScope_Input, 1, &enable,
                                        UInt32(MemoryLayout<UInt32>.size)) == noErr)
            
            let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false);
            assert(AudioUnitSetProperty(aUnit, kAudioUnitProperty_StreamFormat,
                                        kAudioUnitScope_Output, 1, format?.streamDescription,
                                        UInt32(MemoryLayout<AudioStreamBasicDescription>.size)) == noErr)
            
            let iProc:AURenderCallback = inputCallback;
            var inputCallback = AURenderCallbackStruct(inputProc: iProc,
                                                       inputProcRefCon: UnsafeMutableRawPointer(audioUnit))
            
            assert(AudioUnitSetProperty(aUnit, kAudioOutputUnitProperty_SetInputCallback,
                                 kAudioUnitScope_Global, 1, &inputCallback,
                                 UInt32(MemoryLayout<AURenderCallbackStruct>.size)) == noErr)
            
            assert(AudioUnitInitialize(aUnit) == noErr)
            
            assert(AudioOutputUnitStart(aUnit) == noErr)
        } else {
            fatalError()
        }
        
        sleep(10
        )
        
    }
    
    func testGraphForEarReturn() {
        var acdesc = AudioComponentDescription()
        acdesc.componentType         = kAudioUnitType_Output
        acdesc.componentSubType      = kAudioUnitSubType_VoiceProcessingIO
        acdesc.componentManufacturer = kAudioUnitManufacturer_Apple
        acdesc.componentFlags        = 0
        acdesc.componentFlagsMask    = 0
        
        var graph: AUGraph? = nil
        assert(NewAUGraph(&graph) == noErr)
        guard let g = graph else {
            fatalError()
        }
        
        assert(AUGraphOpen(g) == noErr)
        var node: AUNode = 0
        assert(AUGraphAddNode(g, &acdesc, &node) == noErr)
        
        var unit: AudioUnit? = nil
        assert(AUGraphNodeInfo(g, node, &acdesc, &unit) == noErr)
        
        var enable: UInt32 = 1
        assert(AudioUnitSetProperty(unit!, kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Input, 1, &enable,
                                    UInt32(MemoryLayout<UInt32>.size)) == noErr)
        
        assert(AudioUnitSetProperty(unit!, kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Output, 0, &enable,
                                    UInt32(MemoryLayout<UInt32>.size)) == noErr)
        
        assert(AUGraphConnectNodeInput(g, node, 1, node, 0) == noErr)
        
        assert(AUGraphInitialize(g) == noErr)
        
        assert(AUGraphStart(g) == noErr)
        
        sleep(10)
        
    }
    
    func testGraphForCallbacks() {
        var acdesc = AudioComponentDescription()
        acdesc.componentType         = kAudioUnitType_Output
        acdesc.componentSubType      = kAudioUnitSubType_VoiceProcessingIO
        acdesc.componentManufacturer = kAudioUnitManufacturer_Apple
        acdesc.componentFlags        = 0
        acdesc.componentFlagsMask    = 0
        
        var graph: AUGraph? = nil
        assert(NewAUGraph(&graph) == noErr)
        guard let g = graph else {
            fatalError()
        }
        
        assert(AUGraphOpen(g) == noErr)
        var node: AUNode = 0
        assert(AUGraphAddNode(g, &acdesc, &node) == noErr)
        
        var unit: AudioUnit! = nil
        assert(AUGraphNodeInfo(g, node, &acdesc, &unit) == noErr)
        
        var enable: UInt32 = 1
        assert(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Input, 1, &enable,
                                    UInt32(MemoryLayout<UInt32>.size)) == noErr)
        
        assert(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Output, 0, &enable,
                                    UInt32(MemoryLayout<UInt32>.size)) == noErr)
        
        let iProc:AURenderCallback = inputCallback;
        var inputCallback = AURenderCallbackStruct(inputProc: iProc,
                                                   inputProcRefCon: UnsafeMutableRawPointer(unit))
        
        assert(AudioUnitSetProperty(unit, kAudioOutputUnitProperty_SetInputCallback,
                             kAudioUnitScope_Global, 1, &inputCallback,
                             UInt32(MemoryLayout<AURenderCallbackStruct>.size)) == noErr)
        
        assert(AUGraphConnectNodeInput(g, node, 1, node, 0) == noErr)
        
        assert(AUGraphInitialize(g) == noErr)
        
        assert(AUGraphStart(g) == noErr)
        
        sleep(10)
        
    }
    
    func testAddTwoIOUnitToGraph() {
        var apioDesc = AudioComponentDescription()
        apioDesc.componentType         = kAudioUnitType_Output
        apioDesc.componentSubType      = kAudioUnitSubType_VoiceProcessingIO
        apioDesc.componentManufacturer = kAudioUnitManufacturer_Apple
        apioDesc.componentFlags        = 0
        apioDesc.componentFlagsMask    = 0
        
        var rioDesc = AudioComponentDescription()
        rioDesc.componentType         = kAudioUnitType_Output
        rioDesc.componentSubType      = kAudioUnitSubType_RemoteIO
        rioDesc.componentManufacturer = kAudioUnitManufacturer_Apple
        rioDesc.componentFlags        = 0
        rioDesc.componentFlagsMask    = 0
        
        var graph: AUGraph? = nil
        assert(NewAUGraph(&graph) == noErr)
        guard let g = graph else {
            fatalError()
        }
        
        var vpioNode: AUNode = 0
        assert(AUGraphAddNode(g, &apioDesc, &vpioNode) == noErr)
        
    
        var rioNode: AUNode = 0
        assert(AUGraphAddNode(g, &rioDesc, &rioNode) == kAUGraphErr_OutputNodeErr)
    }
    
    func testAVAudioEngineMixingAudio() {
        guard let path = Bundle(for: Self.self) .path(forResource: "Synth", ofType: "aif") else { fatalError() }
        let speechURL = URL.init(fileURLWithPath: path)
        //guard let speechURL = Bundle.main.url(forResource: "sample", withExtension: "wav") else { fatalError() }
        let file: AVAudioFile!
        do {
            let e = AVAudioEngine()
            let input = e.inputNode
            let mainMixer = e.mainMixerNode
            let output = e.outputNode
            let playerNode = AVAudioPlayerNode()
            e.attach(playerNode)
            
            try input.setVoiceProcessingEnabled(true)
            try file = AVAudioFile(forReading: speechURL)
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                          frameCapacity: AVAudioFrameCount(file.length))
            guard let speechBuffer = buffer else {
                fatalError()
            }
            file.framePosition = 0
            try file.read(into: speechBuffer)
            file.framePosition = 0
            
            e.connect(input, to: mainMixer, format: input.outputFormat(forBus: 1))
            e.connect(playerNode, to: mainMixer, format: speechBuffer.format)
            e.connect(mainMixer, to: output, format: mainMixer.outputFormat(forBus: 0))
            e.prepare()
            try e.start()
            playerNode.scheduleBuffer(speechBuffer, at: nil, options: .loops)
            playerNode.play()
            sleep(10)
        } catch {
            print()
            fatalError("Could not load file: \(error)")
        }
        

    }
    
    func testInputAndOutputNode() {
        let input0 = engine.inputNode;
        let input1 = engine1.inputNode;
        
        XCTAssertNotEqual(input0.audioUnit, input1.audioUnit);
        //XCTAssertEqual(input.auAudioUnit, output.auAudioUnit)
    }


    func testEnineNumberOfBus() {
        let input = engine.inputNode
        XCTAssertEqual(input.numberOfInputs, 1);
        XCTAssertEqual(input.numberOfOutputs, 1)
        
        let output = engine.outputNode
        XCTAssertEqual(output.numberOfInputs, 1);
        XCTAssertEqual(output.numberOfOutputs, 1)
    }
    
    func testEngineOutputNodeFormat() {
        let output = engine.outputNode
        var format = output.inputFormat(forBus: 0)
        print("outputNode format:\(format)")
        printASBD(asbd: format.streamDescription)
    
        format = output.outputFormat(forBus: 0)
        print("outputNode format:\(format)")
        printASBD(asbd: format.streamDescription)
    }
    
    func testEngineInputNodeFormat() {
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 1)
        print("inputNode format:\(format)")
        printASBD(asbd: format.streamDescription)
        
        guard let tempFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                                 sampleRate: AVAudioSession.sharedInstance().sampleRate,
                                                 channels: AVAudioChannelCount(1),
                                          interleaved: false) else {fatalError() }
        print("tempFormat: \(tempFormat)")
        printASBD(asbd: tempFormat.streamDescription)
    }
    
    func testEngineVoiceProcessingIONodes() {
        let input = engine.inputNode
        do {
            try input.setVoiceProcessingEnabled(true)
        } catch {
        }
        print("input unit desc:\(input.auAudioUnit.componentDescription)")
        print("input unit componentName:\(input.auAudioUnit.componentName ?? "unknow")")
        print("input unit audioUnitName:\(input.auAudioUnit.audioUnitName ?? "unknow")")
        print("input unit component:\(input.auAudioUnit.component)")
        print("input unit audio_unit:\(String(describing: input.audioUnit))")
        print("input unit auaudio_unit:\(String(describing: input.auAudioUnit))")
        print("input unit input enabled:\(input.auAudioUnit.isInputEnabled)")
        print("input unit output enabled:\(input.auAudioUnit.isOutputEnabled)")

        XCTAssertEqual(input.auAudioUnit.componentDescription.componentType, kAudioUnitType_Output)
        XCTAssertEqual(input.auAudioUnit.componentDescription.componentSubType, kAudioUnitSubType_VoiceProcessingIO)
        XCTAssertEqual(input.auAudioUnit.componentDescription.componentManufacturer, kAudioUnitManufacturer_Apple)

        let output = engine.outputNode
        print("output unit desc:\(output.auAudioUnit.componentDescription)")
        print("output unit componentName:\(output.auAudioUnit.componentName ?? "unknow")")
        print("output unit audioUnitName:\(output.auAudioUnit.audioUnitName ?? "unknow")")
        print("output unit component:\(output.auAudioUnit.component)")
        print("output unit audio_unit:\(String(describing: output.audioUnit))")
        print("output unit auaudio_unit:\(String(describing: output.auAudioUnit))")
        print("output unit input enabled:\(output.auAudioUnit.isInputEnabled)")
        print("output unit output enabled:\(output.auAudioUnit.isOutputEnabled)")

        XCTAssertEqual(output.auAudioUnit.componentDescription.componentType, kAudioUnitType_Output)
        XCTAssertEqual(output.auAudioUnit.componentDescription.componentSubType, kAudioUnitSubType_VoiceProcessingIO)
        XCTAssertEqual(output.auAudioUnit.componentDescription.componentManufacturer, kAudioUnitManufacturer_Apple)


        XCTAssertNotEqual(input, output)
        XCTAssertEqual(input.audioUnit, output.audioUnit);
        XCTAssertEqual(input.auAudioUnit, output.auAudioUnit)
        XCTAssertEqual(input.auAudioUnit.audioUnitName, output.auAudioUnit.audioUnitName)
    }
    
    func testEngineInputAndOutputNode() {
        let input = engine.inputNode
        print("input unit desc:\(input.auAudioUnit.componentDescription)")
        print("input unit componentName:\(input.auAudioUnit.componentName ?? "unknow")")
        print("input unit audioUnitName:\(input.auAudioUnit.audioUnitName ?? "unknow")")
        print("input unit component:\(input.auAudioUnit.component)")
        print("input unit audio_unit:\(String(describing: input.audioUnit))")
        print("input unit auaudio_unit:\(String(describing: input.auAudioUnit))")
        print("input unit input enabled:\(input.auAudioUnit.isInputEnabled)")
        print("input unit output enabled:\(input.auAudioUnit.isOutputEnabled)")

        XCTAssertEqual(input.auAudioUnit.componentDescription.componentType, kAudioUnitType_Output)
        XCTAssertEqual(input.auAudioUnit.componentDescription.componentSubType, kAudioUnitSubType_RemoteIO)
        XCTAssertEqual(input.auAudioUnit.componentDescription.componentManufacturer, kAudioUnitManufacturer_Apple)

        let output = engine.outputNode
        print("output unit desc:\(output.auAudioUnit.componentDescription)")
        print("output unit componentName:\(output.auAudioUnit.componentName ?? "unknow")")
        print("output unit audioUnitName:\(output.auAudioUnit.audioUnitName ?? "unknow")")
        print("output unit component:\(output.auAudioUnit.component)")
        print("output unit audio_unit:\(String(describing: output.audioUnit))")
        print("output unit auaudio_unit:\(String(describing: output.auAudioUnit))")
        print("output unit input enabled:\(output.auAudioUnit.isInputEnabled)")
        print("output unit output enabled:\(output.auAudioUnit.isOutputEnabled)")
        
        XCTAssertEqual(output.auAudioUnit.componentDescription.componentType, kAudioUnitType_Output)
        XCTAssertEqual(output.auAudioUnit.componentDescription.componentSubType, kAudioUnitSubType_RemoteIO)
        XCTAssertEqual(output.auAudioUnit.componentDescription.componentManufacturer, kAudioUnitManufacturer_Apple)
        
        
        XCTAssertNotEqual(input, output)
        XCTAssertEqual(input.audioUnit, output.audioUnit);
        XCTAssertEqual(input.auAudioUnit, output.auAudioUnit)
        XCTAssertEqual(input.auAudioUnit.audioUnitName, output.auAudioUnit.audioUnitName)
        
    }
    
    func testEngine() {
        let e = AVAudioEngine()
        let input = e.inputNode
        XCTAssertEqual(input.auAudioUnit.componentDescription.componentType, kAudioUnitType_Output)
        XCTAssertEqual(input.auAudioUnit.componentDescription.componentSubType, kAudioUnitSubType_RemoteIO)
        XCTAssertEqual(input.auAudioUnit.componentDescription.componentManufacturer, kAudioUnitManufacturer_Apple)

        let output = e.outputNode
        XCTAssertEqual(output.auAudioUnit.componentDescription.componentType, kAudioUnitType_Output)
        XCTAssertEqual(output.auAudioUnit.componentDescription.componentSubType, kAudioUnitSubType_RemoteIO)
        XCTAssertEqual(output.auAudioUnit.componentDescription.componentManufacturer, kAudioUnitManufacturer_Apple)
        
        XCTAssertNotEqual(input, output)
        XCTAssertEqual(input.audioUnit, output.audioUnit);
        XCTAssertEqual(input.auAudioUnit, output.auAudioUnit)
        XCTAssertEqual(input.auAudioUnit.audioUnitName, output.auAudioUnit.audioUnitName)
    }

    func testAVAudioInputNode() {
        print("Subtype_RemoteIO: \(kAudioUnitSubType_RemoteIO)")
        print("Subtype_voiceIO: \(kAudioUnitSubType_VoiceProcessingIO)")
        print("UnitType_Ouput:\(kAudioUnitType_Output)")
        
        let input = engine.inputNode
        print("input unit desc:\(input.auAudioUnit.componentDescription)")
        print("input unit componentName:\(input.auAudioUnit.componentName ?? "unknow")")
        print("input unit audioUnitName:\(input.auAudioUnit.audioUnitName ?? "unknow")")
        print("input unit component:\(input.auAudioUnit.component)")
        print("input unit audio_unit:\(String(describing: input.audioUnit))")
        print("output unit auaudio_unit:\(String(describing: input.auAudioUnit))")
        
        XCTAssertEqual(input.auAudioUnit.componentDescription.componentType, kAudioUnitType_Output)
        XCTAssertEqual(input.auAudioUnit.componentDescription.componentSubType, kAudioUnitSubType_RemoteIO)
        XCTAssertEqual(input.auAudioUnit.componentDescription.componentManufacturer, kAudioUnitManufacturer_Apple)
        
        do {
            try input.setVoiceProcessingEnabled(true);
        } catch {
              print("could not enabled voice processing \(error)")
        }
        print("=====================================")
        print("input unit desc:\(input.auAudioUnit.componentDescription)")
        print("input unit componentName:\(input.auAudioUnit.componentName ?? "unknow")")
        print("input unit audioUnitName:\(input.auAudioUnit.audioUnitName ?? "unknow")")
        print("input unit component:\(input.auAudioUnit.component)")
        print("input unit audio_unit:\(String(describing: input.audioUnit))")
        print("output unit auaudio_unit:\(String(describing: input.auAudioUnit))")
        print("input unit number of inputs:\(input.numberOfInputs)")
        print("input unit number of inputs:\(input.numberOfOutputs)")
        print("input unit input enabled:\(input.auAudioUnit.isInputEnabled)")
        print("input unit output enabled:\(input.auAudioUnit.isOutputEnabled)")
        
        XCTAssertEqual(input.auAudioUnit.componentDescription.componentType, kAudioUnitType_Output)
        XCTAssertEqual(input.auAudioUnit.componentDescription.componentSubType, kAudioUnitSubType_VoiceProcessingIO)
        XCTAssertEqual(input.auAudioUnit.componentDescription.componentManufacturer, kAudioUnitManufacturer_Apple)
    }
    
    func testAVAudioOutputNode() {
        print("Subtype_RemoteIO: \(kAudioUnitSubType_RemoteIO)")
        print("Subtype_voiceIO: \(kAudioUnitSubType_VoiceProcessingIO)")
        print("UnitType_Ouput:\(kAudioUnitType_Output)")
        
        let output = engine.outputNode
        print("output unit desc:\(output.auAudioUnit.componentDescription)")
        print("output unit componentName:\(output.auAudioUnit.componentName ?? "unknow")")
        print("output unit audioUnitName:\(output.auAudioUnit.audioUnitName ?? "unknow")")
        print("output unit component:\(output.auAudioUnit.component)")
        print("output unit audio_unit:\(String(describing: output.audioUnit))")
        print("output unit auaudio_unit:\(String(describing: output.auAudioUnit))")
        print("output unit input enabled:\(output.auAudioUnit.isInputEnabled)")
        print("output unit output enabled:\(output.auAudioUnit.isOutputEnabled)")
        
        XCTAssertEqual(output.auAudioUnit.componentDescription.componentType, kAudioUnitType_Output)
        XCTAssertEqual(output.auAudioUnit.componentDescription.componentSubType, kAudioUnitSubType_RemoteIO)
        XCTAssertEqual(output.auAudioUnit.componentDescription.componentManufacturer, kAudioUnitManufacturer_Apple)
    }
    
    func testAVAudioPlayerNode() {
        print("Subtype_RemoteIO: \(kAudioUnitSubType_RemoteIO)")
        print("Subtype_voiceIO: \(kAudioUnitSubType_VoiceProcessingIO)")
        print("UnitType_Ouput:\(kAudioUnitType_Output)")
        print("SubType_ScheduledSoundPlayer:\(kAudioUnitSubType_ScheduledSoundPlayer)")
        let playerNode = AVAudioPlayerNode()
        print("playerNode unit desc:\(playerNode.auAudioUnit.componentDescription)")
        print("playerNode unit componentName:\(playerNode.auAudioUnit.componentName ?? "unknow")")
        print("playerNode unit audioUnitName:\(playerNode.auAudioUnit.audioUnitName ?? "unknow")")
        print("playerNode unit component:\(playerNode.auAudioUnit.component)")
        print("playerNode unit auaudio_unit:\(String(describing: playerNode.auAudioUnit))")
        
        //print("output unit input enabled:\(playerNode.auAudioUnit.isInputEnabled)")
        //print("output unit output enabled:\(playerNode.auAudioUnit.isOutputEnabled)")
        XCTAssertEqual(playerNode.auAudioUnit.componentDescription.componentType, kAudioUnitType_Generator)
        XCTAssertEqual(playerNode.auAudioUnit.componentDescription.componentSubType, kAudioUnitSubType_ScheduledSoundPlayer)
        XCTAssertEqual(playerNode.auAudioUnit.componentDescription.componentManufacturer, kAudioUnitManufacturer_Apple)
    }
    
    func testAVAudioMixerNode() {
        let mixer = AVAudioMixerNode()
        print("playerNode unit desc:\(mixer.auAudioUnit.componentDescription)")
        print("playerNode unit componentName:\(mixer.auAudioUnit.componentName ?? "unknow")")
        print("playerNode unit audioUnitName:\(mixer.auAudioUnit.audioUnitName ?? "unknow")")
        print("playerNode unit component:\(mixer.auAudioUnit.component)")
        print("playerNode unit auaudio_unit:\(String(describing: mixer.auAudioUnit))")
               
    }
    
    func testAVAudioType() {
        print("UnitType_Ouput:\(kAudioUnitType_Output)")
        
        print("UnitType_MusicDevice:\(kAudioUnitType_MusicDevice)")
        print("UnitType_MusicEffect:\(kAudioUnitType_MusicEffect)")
        print("UnitType_FormatConverter:\(kAudioUnitType_FormatConverter)")
        print("UnitType_Effect:\(kAudioUnitType_Effect)")
        print("UnitType_Mixer:\(kAudioUnitType_Mixer)")
        print("UnitType_Panner:\(kAudioUnitType_Panner)")
        print("UnitType_Generator:\(kAudioUnitType_Generator)")
        print("UnitType_OfflineEffect:\(kAudioUnitType_OfflineEffect)")
        print("UnitType_MIDIProcessor:\(kAudioUnitType_MIDIProcessor)")

    }
    
    func testUnsafeMutablePointer() {
        let mData = UnsafeMutablePointer<Int8>.allocate(capacity: 4096);
        mData.initialize(repeating: 0, count: 4096)
        mData.deinitialize(count: 4096)
        mData.deallocate()
    }

    func testOpenAudioFileErrorCode() {
        print("kAudioFileUnspecifiedError:               \(kAudioFileUnspecifiedError)")
        print("kAudioFileUnsupportedFileTypeError:       \(kAudioFileUnsupportedFileTypeError)")
        print("kAudioFileUnsupportedDataFormatError:     \(kAudioFileUnsupportedDataFormatError)")
        print("kAudioFileUnsupportedPropertyError:       \(kAudioFileUnsupportedPropertyError)")
        print("kAudioFileBadPropertySizeError:           \(kAudioFileBadPropertySizeError)")
        print("kAudioFileNotOptimizedError:              \(kAudioFileNotOptimizedError)")
        print("kAudioFileInvalidChunkError:              \(kAudioFileInvalidChunkError)")
        print("kAudioFileDoesNotAllow64BitDataSizeError: \(kAudioFileDoesNotAllow64BitDataSizeError)")
        print("kAudioFileInvalidPacketOffsetError:       \(kAudioFileInvalidPacketOffsetError)")
        print("kAudioFileInvalidFileError:               \(kAudioFileInvalidFileError)")
        print("kAudioFileOperationNotSupportedError:     \(kAudioFileOperationNotSupportedError)")
        print("kAudioFileNotOpenError:                   \(kAudioFileNotOpenError)")
        print("kAudioFileEndOfFileError:                 \(kAudioFileEndOfFileError)")
        print("kAudioFilePositionError:                  \(kAudioFilePositionError)")
        print("kAudioFileFileNotFoundError:              \(kAudioFileFileNotFoundError)")
    }
    
    func testAVAssetReaderOutput() {
        guard let path = Bundle(for: Self.self) .path(forResource: "test", ofType: "MP4") else { fatalError() }
        let videoURL = URL.init(fileURLWithPath: path)
        let asset = AVAsset(url: videoURL)
        guard let audioTrack  = asset.tracks(withMediaType: .audio).first else {
            fatalError()
        }
        let audioTrackOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [AVFormatIDKey:               kAudioFormatLinearPCM])
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            fatalError()
        }
        let videoTrackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatContainsYCbCr])
        var assetReader: AVAssetReader!
        do {
            assetReader = try AVAssetReader(asset: asset)
        } catch {
            
        }
        
        if assetReader.canAdd(audioTrackOutput) {
            assetReader.add(audioTrackOutput)
        }
        if assetReader.canAdd(videoTrackOutput) {
            assetReader.add(videoTrackOutput)
        }
        assetReader.startReading()
        
        var done = false
        while !done {
            let audioSample = audioTrackOutput.copyNextSampleBuffer()
            let videoSample = videoTrackOutput.copyNextSampleBuffer()
            if  let audioBuffer = audioSample {
                let duration = audioBuffer.duration
                let pts = audioBuffer.presentationTimeStamp
                
                print("audio pts:", terminator: " ")
                CMTimeShow(pts)
                print("audio duration:", terminator: " ")
                CMTimeShow(duration)
            }
            
            if let videoBuffer = videoSample {
                let duration = CMSampleBufferGetDuration(videoBuffer)
                let pts = CMSampleBufferGetPresentationTimeStamp(videoBuffer)
                print("video pts:", terminator: " ")
                CMTimeShow(pts)
                print("video duration:", terminator: " ")
                CMTimeShow(duration)
            }
            
            if assetReader.status == .completed {
                done = true
                print("assert reader status is completed")
            } else if assetReader.status != .reading {
                print("assert reader status is \(assetReader.status.rawValue)")
                break
            }
            
        }
    }
    
    
    func testAVAssetReaderOutput1() {
        guard let path = Bundle(for: Self.self) .path(forResource: "test", ofType: "MP4") else { fatalError() }
        let videoURL = URL.init(fileURLWithPath: path)
        let asset = AVAsset(url: videoURL)
        guard let audioTrack  = asset.tracks(withMediaType: .audio).first else {
            fatalError()
        }
        let audioSettings: [String : Any] = [AVFormatIDKey:               kAudioFormatLinearPCM,
                                             AVSampleRateKey:             48000,
                                             AVNumberOfChannelsKey:       1,
                                             AVLinearPCMIsNonInterleaved: false,
                                             AVLinearPCMBitDepthKey:      32,
                                             AVLinearPCMIsFloatKey:       true,
                                             AVLinearPCMIsBigEndianKey:   true]
        let audioTrackOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: audioSettings)
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            fatalError()
        }
        let videoTrackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatContainsYCbCr])
        var assetReader: AVAssetReader!
        do {
            assetReader = try AVAssetReader(asset: asset)
        } catch {
            
        }
        
        if assetReader.canAdd(audioTrackOutput) {
            assetReader.add(audioTrackOutput)
        }
        if assetReader.canAdd(videoTrackOutput) {
            assetReader.add(videoTrackOutput)
        }
        assetReader.startReading()
        
        var done = false
        while !done {
            let audioSample = audioTrackOutput.copyNextSampleBuffer()
            let videoSample = videoTrackOutput.copyNextSampleBuffer()
            if  let audioBuffer = audioSample {
                let duration = audioBuffer.duration
                let pts = audioBuffer.presentationTimeStamp
                
                print("audio pts:", terminator: " ")
                CMTimeShow(pts)
                print("audio duration:", terminator: " ")
                CMTimeShow(duration)
                if var asbd = audioBuffer.formatDescription?.audioStreamBasicDescription {
                    printASBD(asbd: &asbd)
                }
            }
            
            if let videoBuffer = videoSample {
                let duration = CMSampleBufferGetDuration(videoBuffer)
                let pts = CMSampleBufferGetPresentationTimeStamp(videoBuffer)
                print("video pts:", terminator: " ")
                CMTimeShow(pts)
                print("video duration:", terminator: " ")
                CMTimeShow(duration)
            }
            
            if assetReader.status == .completed {
                done = true
                print("assert reader status is completed")
            } else if assetReader.status != .reading {
                print("assert reader status is \(assetReader.status.rawValue)")
                break
            }
            
        }
    }
    
    func testAVFormat() {
        if let aformat1 = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 1, interleaved: false)  {
            printASBD(asbd: aformat1.streamDescription)
        }
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
