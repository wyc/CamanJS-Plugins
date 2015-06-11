###
Wind - A filter used to create motion blur

Algorithmic inspiration from the GIMP project.

Version:   0.1
Author:    wyc
Contact:   wyc@fastmail.fm
Website:   https://wyc.io

Copyright (c) 2015 WYC Technology

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
###

Caman.Plugin.register "wind", (
    threshold, # derivative comparison for edge detection
    direction, # flow of wind "left" or "right"
    strength,  # how many pixels to bleed
    edge       # do we bleed on the start or end of an edge, or both?
) ->
    return if isNaN(threshold) or threshold < 1
    return if direction != "left" && direction != "right"
    return if isNaN(strength) or strength < 1
    return if edge != "leading" && edge != "trailing" && edge != "both"
    console.log "Got Params"

    pixels = @pixelData
    width = @dimensions.width
    height = @dimensions.height
    console.log "Pixel data length: " + @pixelData.length + " bytes"

    # thresholdExceeded finds out if the pixels at pIdx1 and pIdx2 meet the
    # differential threshold. It averages all components of each pixel and
    # checks against the threshold parameter. Returns true or false.
    thresholdExceeded = (pIdx1, pIdx2) ->
        deltas = []
        deltas[i] = pixels[pIdx1 + i] - pixels[pIdx2 + i] for i in [0..3]
        deltas[i] = Math.abs(v) for v, i in deltas if edge is "both"
        deltas[i] = -v          for v, i in deltas if edge is "leading"
        # do nothing for "trailing"
        sum = 0; sum += v for v in deltas
        (sum / 4) > threshold


    # cap limits the given value to the range of [0,255]
    cap = (v) ->
        switch
            when v < 0   then 0
            when v > 255 then 255
            else Math.floor(v)

    # processRow applies randomly weighted bleeding on a row's pixels passing
    # a threshold edge check.
    processRow = (rowNum) ->
        col = 0; baseIdx = rowNum * 4 * width
        while col < width - 2
            pIdx1 = baseIdx + col * 4; pIdx2 = pIdx1 + 4
            if not thresholdExceeded pIdx1, pIdx2
                ++col
                continue


            # 25% chance of longer bleeding
            bleedLenMax = switch
                when Math.random() > 0.25 then strength
                else 4 * strength
            bleedLen = 1 + Math.floor(Math.random() * bleedLenMax)
            startCol = col + 1
            endCol = switch
                when col + bleedLen > width - 1 then width - 1
                else col + bleedLen

            blendColor = []; targetColor = []; deltaColor = []
            for i in [0..3]
                blendColor[i]  = pixels[pIdx1 + i]
                targetColor[i] = pixels[pIdx2 + i]
                deltaColor[i]  = targetColor[i] - blendColor[i]

            #pixels[pIdx1] = 255
            #pixels[pIdx1 + 1] = 0
            #pixels[pIdx1 + 2] = 0

            # start drawing the bleed
            n = bleedLen
            denominator = 2.0 / (n * n + n) # used to keep values sane as n decreases
            for c in [startCol..endCol - 1]
                pIdx = baseIdx + c * 4
                break if Math.random() < 0.5 and not (thresholdExceeded pIdx1, pIdx)

                for i in [0..3]
                    blendColor[i] += cap deltaColor[i] * n * denominator
                    pixels[pIdx + i] = (2 * blendColor[i] + pixels[pIdx + i]) / 3
                if thresholdExceeded pIdx, pIdx + 4
                    for i in [0..3]
                        targetColor[i] = pixels[pIdx + 4 + i]
                        deltaColor[i]  = targetColor[i] - blendColor[i]
                    denominator = 2.0 / (n * n + n)
                n--
            col += endCol - startCol
            endIdx = baseIdx + (endCol - 1) * 4
            #pixels[endIdx] = 0
            #pixels[endIdx + 1] = 255
            #pixels[endIdx + 2] = 0

    processRow m for m in [0..height-1]
    @

Caman.Filter.register "wind", (threshold, direction, strength, edge) ->
    @processPlugin "wind", [threshold, direction, strength, edge]

