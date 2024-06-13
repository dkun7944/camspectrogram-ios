//
//  noise_reveal.metal
//  Camtrogram
//
//  Created by Daniel Kuntz on 6/13/24.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]] half4 noise_reveal(float2 position, SwiftUI::Layer layer, float p) {
    const float edgeWidth = 0.02;
    const float edgeBrightness = 2;
    const float3 innerColor = float3(0.4, 0.8, 1);
    const float3 outerColor = float3(0, 0.5, 1);
    const float noiseScale = 3;

    
}
