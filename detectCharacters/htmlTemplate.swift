//
//  htmlTemplate.swift
//  detectCharacters
//
//  Created by christopher otto on 4/24/19.
//  Copyright © 2019 christopher otto. All rights reserved.
//

import Foundation


let htmlTemplate = """
<!DOCTYPE html>
<html lang="en">

<head>
<meta charset="UTF-8">
<title>%@</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/2.1.2/TweenMax.min.js"></script>
<style>
    body {
        padding: 0px;
        margin: 20px;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol";
    }

    div {
        -webkit-box-sizing: border-box;
        -moz-box-sizing: border-box;
        box-sizing: border-box;
        overflow: hidden;
        position: absolute;
    }

    .checkerboard {
        position: relative;
        border: 1px solid #000000;

        /*https://stackoverflow.com/questions/35361986/css-gradient-checkerboard-pattern*/
        background-image: linear-gradient(45deg, #cecece 25%%, transparent 25%%),
        linear-gradient(-45deg, #cecece 25%%, transparent 25%%),
        linear-gradient(45deg, transparent 75%%, #cecece 75%%),
        linear-gradient(-45deg, transparent 75%%, #cecece 75%%);
        background-size: 20px 20px;
        background-position: 0 0, 0 10px, 10px -10px, -10px 0px;
    }

    .mask {
        overflow: hidden
    }
</style>
</head>

<body>
<div id="ad" class="checkerboard"></div>
<script>
    "use strict";

    var ad = document.getElementById("ad");

    // img coords from Swift app
    var imgData = %@

    function getImageResolution(ImgName) {
        var scalar = 1;
        var filenameArray = ImgName.split(".");

        filenameArray.pop()

        var filename = filenameArray.join(".");

        if (filename.indexOf("@") !== -1 && filename[filename.length - 1] === "x") {
            var temp = filename.substring(filename.indexOf("@") + 1, filename[filename.length]);
            console.log(temp)
            scalar = parseFloat(temp);
        }
        console.log(scalar);

        return 1 / scalar
    }

    // Adds characters to the DOM + returns an object for animations
    // imgData: character data from Swift app.
    // scalar:  adjusts scaling for hi-res images.
    // returns: lines object which holds lines.masks and lines.chars
    function setupText(imgData) {
        var filename = imgData.ImgName.split(".")[0];
        var scalar = getImageResolution(imgData.ImgName);

        var imgW = imgData.ImgW * scalar;
        var imgH = imgData.ImgH * scalar;

        // object to hold masks and characters in separate arrays for each line
        var lines = { masks: [], chars: [] };
        var fragment = document.createDocumentFragment();

        for (var text_line of imgData.TxtLines) {
            var masks = []; // array to hold current line of masks
            var chars = []; // array to hold current line of characters
            for (var txt_char of text_line.CharCoords) {
                // get current coords and multiply by scalar for hi-res graphics
                var charX = txt_char.x * scalar;
                var charY = text_line.Coords.y * scalar;
                var charW = txt_char.w * scalar;
                var charH = text_line.Coords.h * scalar;

                // create mask div to hold character div
                var mask = document.createElement("div");
                mask.classList.add("mask");
                mask.style.height = Math.ceil(charH) + "px";
                mask.style.width = Math.ceil(charW) + "px";
                mask.style.left = Math.round(charX) + "px";
                mask.style.top = Math.round(charY) + "px";

                // create character div with image as offset background
                var char = document.createElement("div");
                char.style.height = Math.ceil(charH) + "px";
                char.style.width = Math.ceil(charW) + "px";
                char.style.backgroundImage = "url('" + imgData.ImgName + "')";
                char.style.backgroundSize = imgW + "px " + imgH + "px";
                char.style.backgroundPosition = (-1 * charX) + "px " + (-1 * charY) + "px";

                mask.appendChild(char);
                fragment.appendChild(mask);

                chars.push(char);
                masks.push(mask);
            }
            lines.chars.push(chars);
            lines.masks.push(masks);

        }
        ad.appendChild(fragment);

        return lines;
    }


    // Sets up ad area used for testing
    function setupAd() {
        var scalar = getImageResolution(imgData.ImgName);

        ad.style.width = imgData.ImgW * scalar + "px";
        ad.style.height = imgData.ImgH * scalar + "px";
    }

    function setupUI() {
        var ui = document.createElement("div");
        ui.innerHTML = "Animation: ";
        ui.style.paddingTop = "1em";
        var typewriterButton = document.createElement("button");
        var elasticButton = document.createElement("button");
        var wordByWordButton = document.createElement("button");

        typewriterButton.addEventListener('click', function() { typewriter(imgData); });
        elasticButton.addEventListener('click', function() { elastic(imgData); });
        wordByWordButton.addEventListener('click', function() { wordByWord(imgData, ['', ''], true); });

        typewriterButton.innerHTML = "Typewriter";
        elasticButton.innerHTML = "Elastic";
        wordByWordButton.innerHTML = "Word by Word";

        ui.appendChild(typewriterButton);
        ui.appendChild(elasticButton);
        ui.appendChild(wordByWordButton);

        document.body.appendChild(ui);
    }

    /*

    Greensock animation functions

    */

    // resets text lines to initial state
    function reset() {
        while (ad.firstChild) {
            ad.removeChild(ad.firstChild);
        }
    }

    // word-by-word animation
    // textArray: an array of the text as strings - ["first line text", "second line text"]
    // useMasks: boolean - set to true for slide-in animations
    function wordByWord(imgData, textArray, useMasks) {
        reset();

        if (textArray.length == 0 || textArray.join("").length == 0) {
            alert("textArray parameter is empty.");
            return false;
        }

        var txtCharArray = setupText(imgData);
        var tl = new TimelineMax({ autoRemoveChildren: true });

        var frameArray = []; // array of text lines
        var yOffsets = []; // holds heights of each line for "slide-up" animations

        for (var i = 0; i < textArray.length; i++) {
            // split string into array of characters
            var chars = textArray[i].split("");

            var lineArray = []; // arrays of words for current line
            var tempArray = []; // array of characters for each word while searching

            // iterator for dom objects - different than text array as it doesn't include spaces
            var j = 0;

            while (chars.length) {
                // remove first character from array
                var char = chars.shift();

                if (char === " ") {
                    // push the tempArray onto the array for the current line
                    // and clear tempArray for next word
                    lineArray.push(tempArray);
                    tempArray = [];
                } else {
                    // add either the mask or char dom object
                    // corresponding to the character to tempArray
                    if (useMasks) {
                        tempArray.push(txtCharArray.chars[i][j]);
                    } else {
                        tempArray.push(txtCharArray.masks[i][j]);
                    }

                    j++;
                }
            }
            lineArray.push(tempArray);
            frameArray.push(lineArray);
        }

        // create array of lineheights for "slide-up" animations
        for (var line of frameArray) {
            yOffsets.push(line[0][0].style.height);
        }

        for (var line of frameArray) {
            tl.staggerFrom(line, 0.25, { autoAlpha: 0, y: [yOffsets], ease: Quad.easeOut }, .05 * i);
        }
    }

    // typewriter animation
    function typewriter(imgData) {
        reset();
        var txtCharArray = setupText(imgData);
        var tl = new TimelineMax({ autoRemoveChildren: true });
        for (let i = 0; i < txtCharArray.chars.length; i++) {
            tl.staggerFrom(txtCharArray.chars[i], 0.01, { autoAlpha: 0, ease: Quad.easeOut }, Math.random() * .15);
        }
    }

    // elastic animation
    function elastic(imgData) {
        reset();
        var txtCharArray = setupText(imgData);
        var tl = new TimelineMax({ autoRemoveChildren: true });
        for (let i = 0; i < txtCharArray.masks.length; i++) {
            tl.staggerFrom(txtCharArray.masks[i], .75, { autoAlpha: 0, scale: 0.01, rotation: Math.random() * 900, ease: Elastic.easeOut }, .05);
        }
    }

    function init() {
        setupAd();
        setupUI();
    }

    window.onload = init;
</script>
</html>
"""

