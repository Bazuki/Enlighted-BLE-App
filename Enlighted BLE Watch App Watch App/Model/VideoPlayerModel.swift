//
//  VideoPlayerModel.swift
//  Enlighted BLE Watch App Watch App
//
//  Created by Dylan Suzuki on 6/7/24.
//  Copyright © 2024 Bryce Suzuki. All rights reserved.
//

import Foundation
import AVFoundation
import SwiftUI
import AVKit

//Credit to: https://stackoverflow.com/questions/29494931/prevent-apple-watch-from-turning-off-the-screen

class VideoPlayerModel: ObservableObject {
    var player = AVPlayer()
    private var avPlayerPlayTask: Task<Void, Never>?
    
    func handleAppear(){
        guard let url = Bundle.main.url(forResource: "enl_logo", withExtension: "mp4") else { return }
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        startAVPlayer()
    }
    
    func handleDisappear(){
        avPlayerPlayTask?.cancel()
        player.replaceCurrentItem(with: nil)
    }
            
    func startAVPlayer() {
        avPlayerPlayTask?.cancel()
        self.avPlayerPlayTask = Task{
            await self.player.seek(to: .zero)
            self.player.play()
            print("playing background video")
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else {
                print("video player cancelled")
                return
            }
            startAVPlayer()
        }
    }
}

struct VideoPlayerView: WKInterfaceObjectRepresentable {
    typealias WKInterfaceObjectType = WKInterfaceInlineMovie
    
    let url: URL = Bundle.main.url(forResource: "enl_logo", withExtension: "mp4")!
    
    func makeWKInterfaceObject(context: Context) -> WKInterfaceInlineMovie {
        let movie = WKInterfaceInlineMovie()
        movie.setMovieURL(url)
        movie.setLoops(true)
        movie.setAutoplays(true)
        movie.setPosterImage(nil)
        DispatchQueue.main.async {
            movie.play()
        }
        return movie
        
    }
    
    func updateWKInterfaceObject(_ wkInterfaceObject: WKInterfaceInlineMovie, context: Context) {
        //no need to update since we just want it to repeat the same thing
    }
    
    
}
